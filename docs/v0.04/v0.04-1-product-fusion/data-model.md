# v0.04-1 Product Fusion — Data Model

## Purpose

This document defines the v0.04-1 data model changes for collapsing catalog metadata into products.

v0.04-1 changes the product model so that `products` becomes the primary item identity table.

This document is the source of truth for v0.04-1 migrations.

---

## Current v0.03 Shape

The current schema separates product metadata across:

```text
catalog_items
catalog_item_identifiers
products
product_variants
```

Current role summary:

| Table                      | v0.03 role                                                  |
| -------------------------- | ----------------------------------------------------------- |
| `catalog_items`            | Descriptive metadata record                                 |
| `catalog_item_identifiers` | ISBN/UPC/local identifiers linked to catalog item           |
| `products`                 | Store-facing product grouping, often linked to catalog item |
| `product_variants`         | Sellable/stockable/orderable SKU                            |

v0.04-1 changes this by moving descriptive metadata into `products`.

---

## Target v0.04-1 Shape

```text
products
  → product_variants
```

Optional future shape, not implemented in this milestone:

```text
product_groups
  → products
    → product_variants
```

Identifier target, not completed in this milestone:

```text
products
  → product_identifiers
```

---

## Migration Strategy

Recommended migration order:

1. Add product metadata fields to `products`.
2. Backfill product fields from linked `catalog_items` (including thumbnail blobs → product `cover_image` where mapped).
3. Update application code to read product fields directly.
4. Update create/import flows, Items index/routing, and `Items::ThumbnailResolver`.
5. Remove or neutralize `products.catalog_item_id` from **runtime** paths (column may remain under Path B).
6. Remove runtime `CatalogItem` model dependency.
7. **Default: Path B** — quarantine `catalog_items` until v0.04-2 (see below). Do not drop the table in v0.04-1 unless identifier/import FK migration is completed in the same branch.

Because `catalog_item_identifiers` and several satellite tables currently depend on `catalog_items`, physical removal must be coordinated with v0.04-2 and v0.04-4 wire-through.

**Data strategy (from [v0.04-0 completion](../../implementation/v0.04-0-completion.md)):** authoritative dev/demo recovery is **reseed** after destructive migrations:

```bash
./dev/rails-docker bin/rails db:drop db:create db:migrate db:seed
./dev/rails-docker bin/rails shelfstack:seeds:validate
```

Backfill migrations are still useful for verifying copy logic; they are not a substitute for reseed in pre-production development.

---

## Table: `products`

## Existing fields to preserve

Keep existing product operational fields unless explicitly replaced:

| Field                             |    Preserve? | Notes                                                                               |
| --------------------------------- | -----------: | ----------------------------------------------------------------------------------- |
| `id`                              |          yes | Primary key                                                                         |
| `name`                            |          yes | May become generated/display field from product metadata and override               |
| `name_override`                   |          yes | Staff override                                                                      |
| `short_name`                      |          yes | Compact display                                                                     |
| `sku`                             | transitional | Optional cached product identifier/search key until v0.04-2; not variant SKU source |
| `product_type`                    |          yes | Review values during migration                                                      |
| `variation_type`                  |          yes | Preserve variant behavior                                                           |
| `list_price_cents`                |          yes | Product-level list/cover price                                                      |
| `default_display_location_id`     |          yes | Preserve resolver behavior                                                          |
| `default_sub_department_id`       |          yes | Preserve classification default behavior                                            |
| `default_inventory_tracking`      |          yes | Preserve inventory resolver behavior                                                |
| `preferred_vendor_id`             |          yes | Preserve vendor sourcing hints                                                      |
| `discountable`                    |          yes | Preserve discount eligibility                                                       |
| `needs_review`                    |          yes | Preserve data quality behavior                                                      |
| `source`                          |          yes | Source of product record                                                            |
| `active`                          |          yes | Active/inactive                                                                     |
| `created_from_buyback_session_id` |          yes | Preserve buyback provenance                                                         |
| `variant1_label`                  |          yes | Preserve matrix/variant support                                                     |
| `variant2_label`                  |          yes | Preserve matrix/variant support                                                     |
| `created_at` / `updated_at`       |          yes | Rails timestamps                                                                    |

## Existing field to remove or replace

| Field             | v0.04-1 action                   | Notes                                                       |
| ----------------- | -------------------------------- | ----------------------------------------------------------- |
| `catalog_item_id` | remove or make transitional only | Active runtime code should not depend on this after v0.04-1 |

If `catalog_item_id` remains temporarily for migration safety, it must not be used by create/read/update runtime flows.

---

## Product metadata fields to add

Move these from `catalog_items` to `products`, preserving names where practical.

| Field                     | Type          | Null / default                                           | Notes                                                                                  |
| ------------------------- | ------------- | -------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `catalog_item_type`       | string        | nullable or defaulted                                    | Consider renaming later to `item_type`; v0.04-1 may keep name for migration simplicity |
| `title`                   | string        | null false                                               | Main title/display title                                                               |
| `subtitle`                | string        | nullable                                                 | Add if not currently present; useful for external data                                 |
| `creators`                | string        | nullable                                                 | Display creator/contributor string                                                     |
| `creator_details`         | jsonb         | nullable                                                 | Structured contributor data                                                            |
| `publisher`               | string        | nullable                                                 | Publisher/manufacturer display                                                         |
| `publisher_details`       | jsonb         | nullable                                                 | Structured publisher/manufacturer data                                                 |
| `publication_date`        | date          | nullable                                                 | Publication/release date                                                               |
| `publication_status`      | string        | null false, default `active`                             | Preserve existing controlled value                                                     |
| `series_name`             | string        | nullable                                                 | Series display                                                                         |
| `series_enumeration`      | string        | nullable, limit 15                                       | Series number/volume                                                                   |
| `series_data`             | jsonb         | nullable                                                 | Structured series data                                                                 |
| `format_id`               | bigint        | nullable initially, eventually required where applicable | References `formats`                                                                   |
| `edition_statement`       | string        | nullable                                                 | Edition/release statement                                                              |
| `language_code`           | string        | nullable, limit 10                                       | Language                                                                               |
| `description`             | text          | nullable                                                 | Description/summary                                                                    |
| `year`                    | string        | nullable, limit 4                                        | Calendar/annual/media year                                                             |
| `bisac_subjects`          | string        | nullable                                                 | Display string                                                                         |
| `bisac_subject_data`      | jsonb         | nullable                                                 | Structured BISAC data                                                                  |
| `genres`                  | string        | nullable                                                 | Display string                                                                         |
| `genre_data`              | jsonb         | nullable                                                 | Structured genre data                                                                  |
| `themes`                  | string        | nullable                                                 | Display string                                                                         |
| `theme_data`              | jsonb         | nullable                                                 | Structured theme data                                                                  |
| `target_audiences`        | string        | nullable                                                 | Display string                                                                         |
| `target_audience_data`    | jsonb         | nullable                                                 | Structured audience data                                                               |
| `access_restrictions`     | string        | nullable                                                 | Display string                                                                         |
| `access_restriction_data` | jsonb         | nullable                                                 | Structured restrictions                                                                |
| `publication_frequency`   | string        | nullable                                                 | Periodical frequency                                                                   |
| `digital`                 | boolean       | null false, default false                                | Existing catalog flag                                                                  |
| `large_print`             | boolean       | null false, default false                                | Existing catalog flag                                                                  |
| `page_count`              | integer       | nullable                                                 | Books                                                                                  |
| `duration_minutes`        | integer       | nullable                                                 | Audio/video/media                                                                      |
| `height`                  | decimal(10,2) | nullable                                                 | Physical dimension                                                                     |
| `width`                   | decimal(10,2) | nullable                                                 | Physical dimension                                                                     |
| `depth`                   | decimal(10,2) | nullable                                                 | Physical dimension                                                                     |
| `dimension_units`         | string        | nullable                                                 | `in`, `cm`, etc.                                                                       |
| `weight`                  | decimal(10,2) | nullable                                                 | Physical weight                                                                        |
| `weight_units`            | string        | nullable                                                 | `g`, `kg`, `lb`, `oz`                                                                  |
| `store_category_id`       | bigint        | nullable                                                 | Transitional if still used; future category assignment may use categorizations         |

### Naming note

For v0.04-1, prefer minimal rename churn.

It is acceptable to preserve names like `catalog_item_type` for one milestone if renaming would add risk. If renamed to `item_type` or `product_kind`, include explicit compatibility handling.

---

## Product display fields

`products.name` should remain available because many views and snapshots depend on it.

Recommended behavior:

```text
products.title        = canonical title / product title
products.name         = generated or cached display name
products.name_override = staff override
```

Suggested rendering rule:

```text
if name_override present:
  display name = name_override
else if title present:
  display name = product metadata rendering
else:
  display name = name
```

Do not remove `products.name` in v0.04-1.

---

## Product attachments (thumbnails)

### Current v0.03

| Attachment           | Model          | Notes                          |
| -------------------- | -------------- | ------------------------------ |
| `primary_thumbnail`  | `CatalogItem`  | Phase 8.5-4; Items index uses  |
| `cover_image`        | `Product`      | Product edit / some imports    |

`Items::ThumbnailResolver` prefers `product.cover_image`, then falls back to `catalog_item.primary_thumbnail`.

### v0.04-1 target

**Canonical attachment:** `Product#cover_image` (`has_one_attached :cover_image` — already exists).

Actions:

1. Backfill: attach catalog `primary_thumbnail` blob to linked product `cover_image` when product has no cover and mapping is unambiguous (1:1 catalog item → product).
2. Update `Items::ThumbnailResolver`, `Items::IndexQuery`, and item overview eager-loads to use product `cover_image` only in active paths.
3. Stop writing new thumbnails to `CatalogItem#primary_thumbnail`.
4. Leave `catalog_items` attachment columns/blobs in place under Path B until table drop; do not read them at runtime after cutover.

Validation (content type, max size) should live on `Product` after cutover; retire or mirror `CatalogItem` thumbnail validations only if table remains temporarily.

---

## Product SKU / Identifier Boundary

`products.sku` currently exists and is unique.

v0.04-1 should treat `products.sku` as transitional.

Rules:

1. `products.sku` may temporarily cache a primary product identifier or local product code.
2. `products.sku` must not be used to generate variant SKUs.
3. `products.sku` is not the final identifier model.
4. v0.04-2 will define `product_identifiers`.
5. v0.04-2 will decide the final variant SKU allocator.

If `products.sku` remains required in the database during v0.04-1, product creation services must assign a safe transitional value.

Possible transitional values:

```text
primary normalized identifier if known
legacy product sku if migrating existing row
generated product placeholder, e.g. P00000042
```

Do not expose transitional SKU rules as permanent domain policy.

---

## Table: `product_variants`

## Preserve

Do not restructure `product_variants` in v0.04-1.

Preserve:

| Field / concern                                  | Notes                                                             |
| ------------------------------------------------ | ----------------------------------------------------------------- |
| `product_id`                                     | Still points to `products`                                        |
| `sku`                                            | Required unique variant SKU; final allocator deferred to v0.04-2  |
| `condition_id`                                   | Preserve new/used/signed/damaged behavior                         |
| `selling_price_cents`                            | Preserve pricing                                                  |
| `inventory_behavior` / inventory tracking fields | Preserve inventory posting gates                                  |
| `sub_department_id`                              | Preserve classification defaults                                  |
| `display_location_id`                            | Preserve merchandising                                            |
| `preferred_vendor_id`                            | Preserve vendor hints                                             |
| `orderable`                                      | Preserve current orderability until v0.04-5 refines used behavior |
| `returnability_status`                           | Preserve                                                          |
| `discountable`                                   | Preserve                                                          |
| attribute fields                                 | Preserve matrix/variant behavior                                  |

## Do not change in v0.04-1

Do not implement final v0.04 used-variant flags unless explicitly scoped:

```text
vendor_orderable
customer_reservable
replenishment_strategy
```

Those belong to v0.04-5.

---

## Table: `catalog_items`

## Target

By the end of v0.04-1, active runtime flows should not depend on `catalog_items`.

### Recommended path: Path B (default)

**Use Path B for v0.04-1** unless the implementation branch also completes v0.04-2 identifier migration and removes all blocking FKs in the same merge.

Path B keeps `catalog_items` as a quarantined/historical table while runtime reads and writes go through `products`.

Two acceptable implementation paths:

### Path A — Drop in v0.04-1

Use only if identifier and import transition can be completed safely **in the same branch**.

Actions:

1. Backfill product metadata and thumbnails.
2. Remove foreign keys and indexes depending on `catalog_items` (see satellite FK inventory below).
3. Remove `products.catalog_item_id`.
4. Drop `catalog_items`.
5. Remove `CatalogItem` model and runtime code.

### Path B — Quarantine until v0.04-2 (default)

Use while `catalog_item_identifiers` and satellite FKs still require `catalog_items`.

Actions:

1. Backfill product metadata and thumbnails.
2. Stop runtime create/read/update dependency on `catalog_items`.
3. Prevent new runtime catalog item creation.
4. Leave table as transitional/historical.
5. Document remaining references (see satellite FK inventory).
6. Assign physical removal to v0.04-2 or v0.04-11.

Either path is acceptable only if the v0.04-1 Definition of Done is met:

```text
No active create/read/update runtime flow requires CatalogItem.
```

---

## Satellite `catalog_item_id` foreign keys

These columns block Path A until migrated or nullable. v0.04-1 must document each; v0.04-2 / v0.04-4 own most renames.

| Table / column | v0.03 role | v0.04-1 runtime action | Follow-up milestone |
| -------------- | ---------- | ---------------------- | ------------------- |
| `products.catalog_item_id` | Links product to catalog metadata | Stop reading/writing in active paths; backfill metadata onto product | Remove column Path A or v0.04-11 |
| `catalog_item_identifiers.catalog_item_id` | Identifier parent | Transitional lookup only; no new identifier features | v0.04-2 → `product_identifiers` |
| `buyback_lines.catalog_item_id` | Intake resolution hint | Retarget intake/resolution to product; stop creating catalog items | v0.04-4 wire-through |
| `buyback_lines.created_catalog_item_id` | Provenance when buyback created catalog row | Retarget to `created_product_id` or equivalent provenance on product | v0.04-4 |
| `customer_request_lines.catalog_item_id` | Demand line catalog hint | Retarget to product; demand remains variant-operational | v0.04-6 demand foundation |
| `external_catalog_imports.catalog_item_id` | Import audit target | Write `product_id` (add column if needed); imports create/update products | v0.04-1 + v0.04-2 |
| `external_lookup_results.local_catalog_item_id` | Local match for ISBNdb lookup | Add/use `local_product_id`; lookup matches products | v0.04-1 + v0.04-2 |

**v0.04-1 minimum:** external lookup/import and Add Item must create or match **products**, not catalog items. Transitional `catalog_item_id` columns may remain nullable for audit/history under Path B but must not drive active create flows.

**Indexes/FKs:** do not drop satellite FKs in v0.04-1 under Path B unless the referencing runtime path is fully retargeted in the same migration.

---

## Table: `catalog_item_identifiers`

## Target

Full replacement is v0.04-2.

v0.04-1 may leave this table in place if needed for transitional lookup or data preservation.

Restrictions:

1. Do not add new feature behavior to `catalog_item_identifiers`.
2. Do not expand identifier types.
3. Do not use this table as the v0.04 identifier model.
4. Document all remaining references.
5. Prepare migration path to `product_identifiers`.

---

## Indexes

## Add indexes to `products`

Recommended indexes:

```ruby
add_index :products, :title
add_index :products, :format_id
add_index :products, :publisher
add_index :products, :publication_date
add_index :products, :series_name
add_index :products, :year
add_index :products, :active
add_index :products, :source
```

Consider trigram or search indexes where existing catalog search used them.

## Remove indexes eventually

If dropping `catalog_items`, remove related indexes automatically with table drop.

If quarantining `catalog_items`, leave existing indexes intact until physical removal.

---

## Constraints

Recommended constraints:

```text
products.title must be present for normal product records
products.year is null or four digits
products.list_price_cents >= 0
products.publication_status is controlled
products.default_inventory_tracking remains controlled
```

Do not over-tighten constraints before seed/import data has been normalized.

Recommended staging:

1. Add nullable columns.
2. Backfill data.
3. Update code.
4. Validate data.
5. Add null constraints where safe.

---

## Foreign Keys

## Preserve

```text
product_variants.product_id → products.id
product_vendors.product_id → products.id
purchase_order_lines.product_variant_id → product_variants.id
receipt_lines.product_variant_id → product_variants.id
inventory ledger entries → product_variants.id
POS lines → product_variants.id
```

## Remove or transition

```text
products.catalog_item_id → catalog_items.id
catalog_item_identifiers.catalog_item_id → catalog_items.id
```

Only remove physical foreign keys when the dependent table migration is safe.

## Add (v0.04-1 transitional)

Optional columns to support product-first external lookup/import while Path B retains `catalog_items`:

| Table | Column | Notes |
| ----- | ------ | ----- |
| `external_lookup_results` | `local_product_id` | FK → `products.id`; replaces runtime use of `local_catalog_item_id` |
| `external_catalog_imports` | `product_id` | FK → `products.id`; audit target for applied imports |

Keep legacy `*_catalog_item_id` columns nullable under Path B for historical rows until v0.04-11 cleanup. New imports must populate product columns.

---

## Backfill Rules

For each existing product with `catalog_item_id`:

1. Load linked catalog item.
2. Copy catalog metadata to product fields.
3. Preserve product operational fields.
4. Preserve product `name`, unless product has no usable name.
5. If product lacks a good `name`, derive from catalog title.
6. Preserve product `list_price_cents`.
7. Preserve product classification/default fields.
8. Mark product `needs_review` if required metadata is missing or conflicts.
9. Record source/provenance where existing fields support it.
10. If catalog item has `primary_thumbnail` and product has no `cover_image`, copy attachment to product `cover_image` (1:1 mapping only; skip or flag ambiguous many-products-per-catalog cases).

Conflict handling:

| Conflict                                             | Rule                                                                                           |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Product name differs from catalog title              | Preserve product name; copy catalog title to `title`; leave `name_override` if already present |
| Product list price differs from catalog metadata     | Preserve product list price                                                                    |
| Product classification differs from catalog category | Preserve product operational classification                                                    |
| Catalog item missing format                          | Allow null temporarily or mark `needs_review`                                                  |
| Multiple products linked to same catalog item        | Copy metadata to each product; this is acceptable because each product becomes independent     |
| Product without catalog item                         | Keep product; populate minimal metadata from product fields                                    |

---

## Seed Rules

Seeds must create products directly.

Seed helpers should stop requiring:

```text
catalog_item:
catalog_item_id:
CatalogItem.find_or_create...
```

Seed helpers should support:

```text
product metadata
product variant data
optional transitional product sku
default subdepartment
default display location
format
source
```

Seed validation should confirm:

1. Products exist with metadata.
2. Product variants exist and remain linked to products.
3. Product creation does not require catalog items.
4. Existing demo flows still have data to run.

---

## Model Changes

## `Product`

Update associations:

```ruby
has_many :product_variants
has_many :product_vendors
```

Remove or quarantine:

```ruby
belongs_to :catalog_item
```

Add validations:

```ruby
validates :title, presence: true
validates :name, presence: true
validates :list_price_cents, numericality: { greater_than_or_equal_to: 0 }
```

Use staged validation if backfill requires temporary nulls.

Add helper methods as needed:

```ruby
# examples only
display_title
display_creator
display_publisher
bibliographic?
metadata_summary
```

## `CatalogItem`

Either:

1. Remove model if physical table is dropped, or
2. Mark model as legacy/transitional and remove from active services/controllers.

If retained temporarily, add comments warning that it is not the v0.04 runtime item model.

## `ProductVariant`

No structural change required in v0.04-1.

Review methods that call through:

```ruby
product.catalog_item
product.catalog_item.title
product.catalog_item.identifiers
```

Rewrite to product fields or defer identifier calls to v0.04-2 boundary services.

---

## Service Changes

Update services that create or read catalog metadata.

Likely affected:

```text
AddItem::*
ExternalCatalog::*
IngramCatalogImport::*
ProductNameRenderer
Items::ItemPresenter
Items::ItemOverviewPresenter
Items::OperationalWarningBuilder
Items::VariantOperationalSnapshot
Buybacks::FindOrCreateGradedUsedVariant
Reports item drill-down helpers
```

Service rule:

```text
Read product metadata from Product.
Do not read product metadata from CatalogItem in active runtime paths.
```

---

## Data Migration Verification Queries

Before migration:

```ruby
Product.where.not(catalog_item_id: nil).count
CatalogItem.count
CatalogItemIdentifier.count
ProductVariant.count
```

After backfill:

```ruby
Product.where(title: [nil, ""]).count
Product.where.not(catalog_item_id: nil).count # should be zero if column retained but cleared
ProductVariant.where(product_id: nil).count
```

If `catalog_items` is quarantined:

```ruby
# Expected only transitional/historical references remain.
```

If `catalog_items` is dropped:

```ruby
ActiveRecord::Base.connection.table_exists?(:catalog_items) # false
```

---

## Documentation Updates

Update:

```text
docs/v0.04/v0.04-1-product-fusion/spec.md
docs/v0.04/v0.04-1-product-fusion/data-model.md
docs/v0.04/v0.04-1-product-fusion/test-plan.md
docs/implementation/v0.04-1-completion.md
```

Do not fully rewrite these until v0.04-11 unless necessary:

```text
docs/domain-model.md
docs/overview.md
docs/schema-reference.md
docs/glossary.md
```

Add notes if they still contain v0.03 vocabulary.
