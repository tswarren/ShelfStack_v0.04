# v0.04-16 Product Entry Revamp — Test Plan

## Status

**Draft**

Spec: [spec.md](spec.md) · Data model: [data-model.md](data-model.md)

---

## Merge gate

```bash
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v00416:verify_product_entry_revamp
```

Verifier checks (minimum):

* MVP formats seeded with eligibility columns
* Genre schemes seeded (`music_genres`, `video_genres`, `video_game_genres`, `sideline_genres`)
* Longest genre `node_key` from CSV imports successfully (scheme-aware max 128)
* `store_categories` node create still rejects `node_key` > 30 chars
* `Products::FieldVisibilityResolver` returns expected visibility for book, music, service, non-inventory
* `Products::FormatEligibility` excludes ineligible formats
* `Products::EntryContext` composes resolver outputs for Add Item and product edit
* `Products::MetadataParamsSanitizer` enforces hidden-field policy on create, edit, and item-kind change
* Add Item book path creates product with correct `catalog_item_type` and no spurious physical fields when digital
* Service / Non-Inventory short form creates correct `product_type` and staff labels (not **Other**); skips normal variant setup
* Legacy format rows remain active; import mappers resolve legacy keys
* Variant edit form does not expose SKU override fields
* Legacy `audiobook` product remains loadable in edit form

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Service — resolver | Field matrix by item kind, digital, format, variation type |
| Service — format eligibility | Filtered format lists |
| Service — operational deriver | `product_type` defaults |
| Service — item kind normalizer | Legacy audiobook/ebook display |
| Service — entry context | Composed visibility, labels, formats, scheme, short-form flag |
| Service — metadata params sanitizer | Hidden-field policy on create, edit, kind change |
| Model — format | Eligibility validations |
| Model — category node | Scheme-aware `node_key` length (30 vs 128) |
| Integration — Add Item | Progressive form per item kind |
| Integration — product edit | Same visibility as Add Item |
| Integration — variant form | Hidden legacy fields, currency price |
| Regression | Import, buyback, orderability, inventory tracking |

---

## Service tests

### `Products::FieldVisibilityResolver`

| Test | Assertion |
| ---- | --------- |
| Book print | Publisher, BISAC, physical fields visible; running time hidden until audiobook format |
| Book digital ebook | Physical hidden; digital formats only |
| Recorded music | Genre scheme visible; BISAC hidden |
| Video | Genre scheme visible; running time visible |
| Calendar | `year` required/visible; digital hidden |
| Sideline | Sideline genre scheme; store category visible |
| Service short form | Only short-form fields visible |
| Non-inventory short form | `product_type` non_inventory; inventory fields hidden |
| Variable variation | Variant label 1 visible |
| Matrix variation | Labels 1 and 2 visible |
| Standard/conditional | Variant labels hidden |

### `Products::FormatEligibility`

| Test | Assertion |
| ---- | --------- |
| Book physical | Includes trade_cloth; excludes ebook |
| Book digital | Includes ebook; excludes trade_cloth |
| Music | Only music formats |
| Cross-kind | Video formats excluded for book |

### `Products::OperationalTypeDeriver`

| Test | Assertion |
| ---- | --------- |
| Book + digital | `product_type` digital |
| Book + print | `product_type` physical |
| Service choice | `product_type` service |
| Non-inventory choice | `product_type` non_inventory |

### `Products::ItemKindNormalizer`

| Test | Assertion |
| ---- | --------- |
| audiobook legacy | Normalizes to book + digital display context |
| ebook legacy | Normalizes to book + digital display context |
| Service product | Staff label **Service** (not Other) |
| Non-inventory product | Staff label **Non-Inventory Item** (not Other) |

### Field labels (`Products::FieldLabelResolver` or visibility helper)

| Test | Assertion |
| ---- | --------- |
| Recorded music | `publisher` field labeled **Label** |
| Video | `publisher` field labeled **Studio** |
| Book | `publisher` field labeled **Publisher** |

### `Products::EntryContext`

| Test | Assertion |
| ---- | --------- |
| Book print | `controlled_scheme` is BISAC; `short_form?` false; eligible formats exclude digital-only |
| Service | `short_form?` true; `operational_product_type` service; `staff_item_kind` service |
| Non-inventory | `short_form?` true; `operational_product_type` non_inventory |
| Composed labels | `field_labels[:publisher]` matches `FieldLabelResolver` for item kind |

### `Products::MetadataParamsSanitizer`

| Test | Assertion |
| ---- | --------- |
| New create | Drops hidden keys from permitted params |
| Edit, kind unchanged | Does not null hidden columns with existing values |
| Edit, kind changed | Clears or flags incompatible BISAC when switching book → music |
| Edit, kind changed | Clears or flags incompatible genre scheme when switching music → video |

---

## Model tests

### `Format` (extended)

* `catalog_item_type` inclusion validation (allowed catalog item types)
* `digital` null means both physical and digital eligible when combined with virtual flag
* Seed idempotency by `format_key`
* Legacy format rows (`hardcover`, `trade_paperback`, etc.) remain active after MVP seed upsert

### `CategoryNode` (scheme-aware `node_key`)

| Test | Assertion |
| ---- | --------- |
| `store_categories` scheme | Rejects `node_key` length 31 |
| `music_genres` scheme | Accepts `node_key` length 81 (sample from seed CSV) |
| `music_genres` scheme | Rejects `node_key` length 129 |
| `bisac` scheme | Still enforces ≤30 |

### Genre scheme seeds

* Schemes exist and are active
* Full CSV trees import idempotently (longest sideline key ~83 chars)
* No duplicate `node_key` per scheme after re-seed

---

## Integration tests

### Add Item (`test/integration/items_add_item_controller_test.rb` — extend)

| Test | Assertion |
| ---- | --------- |
| Non-catalog book print | Creates `catalog_item_type: book`, physical format, visible fields persisted |
| Non-catalog book digital ebook | `digital: true`, ebook format, no height/weight required |
| Service short form | `catalog_item_type: other`, `product_type: service`, minimal fields; skips normal variant setup |
| Non-inventory short form | `product_type: non_inventory`; skips normal variant setup |
| Store category defaults | Selecting store category sets subdepartment/display preview values |
| Variant simplified | New variant without SKU field in form; SKU assigned |

### Product edit (`test/integration/items_products_controller_test.rb` or new contract)

| Test | Assertion |
| ---- | --------- |
| Edit book | BISAC section present |
| Edit music | Genre scheme picker present; BISAC absent |
| Legacy audiobook | Form loads; displays as book context |
| Item kind change | Switching book → music clears or prompts BISAC cleanup |
| Hidden field preserve | Edit book without touching hidden legacy column does not wipe value |

### Product metadata form (`test/integration/items_products_controller_test.rb` or view contract)

| Test | Assertion |
| ---- | --------- |
| `catalog_items/_form` delegate | Renders product metadata partials under `product_forms/metadata/` |
| `edit_metadata` | Uses `Products::EntryContext` for section visibility |

### Variant form (`test/integration/items_product_variants_controller_test.rb` — extend)

| Test | Assertion |
| ---- | --------- |
| New variant | No `name_override` / SKU preview fields |
| Selling price | Accepts decimal currency; stores cents |

### UX contract (optional slice)

| Test | Assertion |
| ---- | --------- |
| Item setup metadata modal | Respects resolver for item kind |

---

## Regression tests

| Area | Assertion |
| ---- | --------- |
| `Items::InventoryTrackingSync` | Still derives from operational `product_type` |
| `ProductVariants::OperationalPolicy` | Service/non-inventory orderability unchanged |
| `Purchasing::OrderEligibilityResolver` | Blocking types still block |
| Ingram import (if covered) | Still creates valid products; legacy format keys map correctly |
| Buyback intake | Book path still works |
| v0.04-15 Overview | Item kind badge still renders from `catalog_item_type` |

---

## Manual verification

1. Add Item → Book (trade paperback): BISAC visible, no genre scheme, physical fields shown
2. Add Item → Book (ebook): digital toggled, ebook format, no dimensions
3. Add Item → Recorded Music: genre picker, no BISAC
4. Add Item → Service: short form only; no sellable SKU wizard step
5. Add Item → Non-Inventory: short form only; no sellable SKU wizard step
6. Product edit → change item kind book → music → BISAC cleared or staff prompted
7. Product edit → change store category → subdepartment/display preview updates
8. Variant edit → selling price as dollars, no SKU field
9. Setup → Formats → MVP list present with correct kind/digital flags; legacy formats still listed

---

## Verifier implementation notes

Rake task `shelfstack:v00416:verify_product_entry_revamp` should:

1. Assert seeded format count ≥ MVP minimum
2. Assert genre scheme keys exist
3. Call resolver and `EntryContext` with fixture contexts (no DB required for pure checks, or use test fixtures)
4. Assert `MetadataParamsSanitizer` drops hidden keys on `:new` mode
5. Optionally smoke one Add Item integration example in test env

Follow pattern from `shelfstack:v00412:verify_demand_ordering_ux`.
