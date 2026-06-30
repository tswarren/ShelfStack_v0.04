# v0.04-2 Product Identifiers — Data Model

## Status

**Planned**

**Functional spec:** [spec.md](spec.md)

---

## Tables

### `product_identifiers`

```ruby
create_table :product_identifiers do |t|
  t.references :product, null: false, foreign_key: true

  t.string :validation_family, null: false   # gtin | isbn | freeform | house
  t.string :identifier_value, null: false
  t.string :normalized_identifier, null: false

  t.string :display_label
  t.string :freeform_scope

  t.boolean :primary_identifier, null: false, default: false
  t.boolean :valid_check_digit
  t.string :validation_message

  t.string :source, null: false, default: "manual"
  t.boolean :active, null: false, default: true
  t.jsonb :metadata, null: false, default: {}

  t.timestamps
end
```

#### Validation families

| Family | Purpose | Validation |
| ------ | ------- | ---------- |
| `gtin` | ISBN-13, EAN-13, EAN-8, UPC-A, GTIN-14 | Digits; lengths 8/12/13/14; GTIN check digit |
| `isbn` | ISBN-10 | Mod-11; last char digit or `X` |
| `freeform` | Publisher numbers, BIPAD, vendor refs, legacy locals | Alphanumeric normalization; no check digit |
| `house` | Store-assigned product EAN-13 | EAN-13 check digit; prefix in active product house segment (`201` in v0.04-2) |

#### Indexes

```ruby
add_index :product_identifiers,
  :normalized_identifier,
  unique: true,
  where: "active = true AND validation_family IN ('gtin', 'house')",
  name: "index_product_identifiers_unique_active_gtin_house"

add_index :product_identifiers,
  [:validation_family, :normalized_identifier],
  unique: true,
  where: "active = true AND validation_family = 'isbn'",
  name: "index_product_identifiers_unique_active_isbn"

add_index :product_identifiers,
  [:product_id, :validation_family, :freeform_scope, :normalized_identifier],
  unique: true,
  where: "active = true AND validation_family = 'freeform'",
  name: "index_product_identifiers_unique_active_freeform_per_product"

add_index :product_identifiers,
  :product_id,
  unique: true,
  where: "active = true AND primary_identifier = true",
  name: "index_product_identifiers_one_active_primary_per_product"
```

**Freeform uniqueness:** scoped to `product_id + freeform_scope + normalized_identifier` — not global.

Recommended `freeform_scope` values:

```text
legacy_local
legacy_product_sku
publisher_number
bipad
vendor_catalog
import_reference
```

---

### `internal_ean_sequences`

Shared allocator for segments `200–229`.

```ruby
create_table :internal_ean_sequences do |t|
  t.string :segment, null: false      # e.g. "201", "211"
  t.string :purpose, null: false      # e.g. "product_house", "variant_sku"
  t.bigint :last_sequence, null: false, default: 0
  t.boolean :active, null: false, default: true

  t.timestamps
end

add_index :internal_ean_sequences, :segment, unique: true
```

Format: `[3-digit prefix][9-digit sequence][EAN-13 check digit]` → 13 digits total.

**Active v0.04-2 segment/purpose pairs:**

| Segment | Purpose |
| ------: | ------- |
| `201` | `product_house` |
| `211` | `variant_sku` |

`22X` and other segments are schema-ready but not generated until owning milestones implement them.

---

### `product_variant_lookup_codes`

```ruby
create_table :product_variant_lookup_codes do |t|
  t.references :product_variant, null: false, foreign_key: true
  t.references :store, null: true, foreign_key: true

  t.string :code, null: false
  t.string :normalized_code, null: false
  t.string :code_type, null: false, default: "manual"

  t.boolean :active, null: false, default: true
  t.integer :priority, null: false, default: 0

  t.timestamps
end
```

Recommended `code_type`: `manual`, `plu`, `menu_key`, `legacy`, `alias`.

```ruby
add_index :product_variant_lookup_codes,
  [:store_id, :normalized_code],
  unique: true,
  where: "active = true AND store_id IS NOT NULL",
  name: "index_variant_lookup_codes_unique_active_store_code"

add_index :product_variant_lookup_codes,
  [:normalized_code],
  unique: true,
  where: "active = true AND store_id IS NULL",
  name: "index_variant_lookup_codes_unique_active_global_code"
```

Normalization: uppercase, trim, allow `A-Z`, `0-9`, hyphen; length 2–12; warn or reject GTIN-length all-numeric values unless explicitly allowed.

---

## Internal EAN segment policy (authoritative)

This policy **supersedes** the older per-category segment table in prior `VERSION_0.04.md` drafts.

| Range | Purpose | v0.04-2 active |
| ----- | ------- | -------------- |
| `20X` | Product-level identification | `201` only |
| `21X` | Variant / copy / unit-level identification | `211` only |
| `22X` | Operational series (SV, tickets, authorizations) | Reserved — not generated |

Examples:

```text
2010000000014   # product house identifier
2110000000011   # product variant SKU
```

---

## Model associations

```ruby
# Product
has_many :product_identifiers
# Product#primary_identifier → active primary product_identifiers row

# ProductVariant
has_many :product_variant_lookup_codes
# sku: required, globally unique; new rows from ProductVariants::SkuAllocator (211)
```

---

## `products.sku` after v0.04-2

| Field | Role after v0.04-2 |
| ----- | ------------------ |
| `products.sku` | Transitional/cache for display, search, legacy joins only |
| `product_identifiers` | Source of truth for product lookup, duplicates, POS product scans, imports |

Sync policy (implementation detail): keep `products.sku` aligned with primary normalized identifier when convenient for search; do not add new behavior that treats it as canonical identity.

---

## Migration: `catalog_item_identifiers` → `product_identifiers`

Path:

```text
catalog_item_identifiers
  → catalog_items
    → products (catalog_item_id)
      → product_identifiers
```

Map legacy `identifier_type`:

| Legacy type | v0.04-2 family |
| ----------- | -------------- |
| `isbn13`, `ean`, `upc`, `gtin` | `gtin` |
| `isbn10` | `isbn` |
| `publisher_number`, `local`, other non-GTIN | `freeform` (with scope) |

### Legacy local (`L...`)

- Preserve as `freeform` / `legacy_local`.
- Do **not** normalize `L...` into `house`.
- Optionally generate new `201` house EAN when scannable product identifier needed.

### Transitional `P...` product SKUs

- Preserve as `freeform` / `legacy_product_sku`.
- Do **not** convert to `house`.

### From bare `products.sku`

Apply rules in [spec.md § Migration rules](spec.md#migration-rules).

---

## Tables removed

| Table | Milestone action |
| ----- | ---------------- |
| `catalog_item_identifiers` | **Drop** after backfill and runtime cutover |
| `catalog_items` | **Retain** — quarantined legacy metadata shell; no identifier ownership |

---

## Verification queries

See `rails shelfstack:v0042:verify_product_identifiers` (test-plan). Minimum counts:

```text
products total
products with identifiers
products with active primary identifier
products without identifiers
product_identifiers by validation_family
duplicate GTIN / ISBN conflicts (must be zero for active rows)
freeform legacy_local / legacy_product_sku counts
internal_ean_sequences counters (201, 211)
remaining catalog_item_identifiers references (must be zero in app/)
```

---

## Related transitional columns (unchanged owner)

| Column | v0.04-2 note |
| ------ | ------------ |
| `products.catalog_item_id` | Deprecated bridge; no new identifier writes via catalog |
| `external_catalog_imports.product_id` | Product-target imports (from v0.04-1) |
| `external_lookup_results.local_product_id` | Local match on products |

Full operational FK cleanup may continue in v0.04-4.
