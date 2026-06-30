# v0.04-1 Product Fusion — Test Plan

## Purpose

This test plan verifies that v0.04-1 successfully moves catalog metadata onto products and removes active runtime dependency on `CatalogItem`.

The goal is to prove:

```text
Product
→ Product Variant
→ operational workflows
```

without requiring:

```text
CatalogItem
```

---

## Test Commands

Run at minimum:

```bash
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails shelfstack:seeds:validate
```

Recommended additional checks:

```bash
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails test:system
./dev/rails-docker bin/rubocop
```

If system tests are slow, run focused system tests for Add Item, Items workspace, POS lookup, receiving, and buyback.

---

## Test Data Requirements

Test fixtures/factories must support creating:

1. Product with metadata directly.
2. Product without catalog item.
3. Product variant linked to product.
4. Product with imported/external metadata.
5. Product created from buyback intake.
6. Product with no external identifier.
7. Product with transitional `products.sku`.
8. Product with multiple variants.
9. Product with classification/default fields.
10. Product with vendor source records.
11. Product with `cover_image` attached (no catalog thumbnail).
12. Product with backfilled cover from legacy catalog thumbnail.

Fixtures should not require `CatalogItem` for new v0.04 tests.

---

## 1. Model Tests

## 1.1 Product metadata

### Test

Create a product directly with metadata fields.

### Assertions

```text
product is valid
product has title
product has format
product has creator/publisher metadata where supplied
product does not require catalog_item_id
product display name renders
```

## 1.2 Product without catalog item

### Test

Create a product with no `catalog_item_id`.

### Assertions

```text
product saves
product can create variants
product can appear in item index
product can appear in item overview
```

## 1.3 Product variant relationship

### Test

Create product and variants.

### Assertions

```text
variant.product == product
product.product_variants includes variant
variant SKU remains unique
variant operational fields remain valid
```

## 1.4 Product name rendering

### Test cases

```text
product with name_override
product with title but no name_override
product with creator/publisher metadata
product with variant condition
```

### Assertions

```text
ProductNameRenderer does not call CatalogItem
rendered product name is correct
rendered variant name is correct
```

## 1.5 CatalogItem runtime dependency guard

### Test

Where practical, remove or stub catalog item associations in product tests.

### Assertions

```text
product show/index paths do not require CatalogItem
product create/update does not require CatalogItem
product variant create/update does not require CatalogItem
```

## 1.6 Product cover image

### Test

Attach `cover_image` to product directly.

### Assertions

```text
attachment validates content type and size on Product
Items::ThumbnailResolver returns cover_image
product valid without catalog item
```

---

## 2. Migration Tests

## 2.1 Backfill existing products

### Setup

Create:

```text
catalog_item with metadata
product linked to catalog_item
variant linked to product
```

### Run

Execute migration/backfill.

### Assertions

```text
product.title copied
product.creator metadata copied
product.publisher metadata copied
product.format copied
product.description copied
product.series/subject metadata copied
product operational fields preserved
variant still linked to product
```

## 2.2 Product conflict preservation

### Setup

Create product whose name/list price/default classification differs from linked catalog item.

### Assertions

```text
product operational name/list/classification preserved where required
catalog metadata copied into metadata fields
needs_review set if conflict requires review
```

## 2.3 Product without catalog item

### Setup

Create product with no `catalog_item_id`.

### Assertions

```text
migration does not fail
product remains valid or is marked needs_review
variant remains valid
```

## 2.4 Multiple products linked to one catalog item

### Setup

Create one catalog item linked to multiple products.

### Assertions

```text
each product receives copied metadata
products remain separate records
variants remain under their existing products
no accidental merge occurs
```

## 2.5 Idempotence

### Test

Run backfill twice.

### Assertions

```text
no duplicate records
no duplicate variants
product metadata remains stable
manual overrides are not overwritten unexpectedly
cover_image backfill is idempotent
```

## 2.6 Thumbnail backfill

### Test

Catalog item with `primary_thumbnail`; linked product without `cover_image`.

### Assertions

```text
backfill attaches blob to product.cover_image
Items::ThumbnailResolver resolves from product after backfill
re-run does not duplicate attachments
```

---

## 3. Add Item Tests

## 3.1 Manual product create

### Test

Create product manually through Add Item or equivalent product creation flow.

### Assertions

```text
product created
product has metadata directly
catalog_item not created
variant optionally created
audit event recorded where expected
```

## 3.2 External catalog candidate import

### Test

Search external catalog, choose candidate, create item.

### Assertions

```text
product created
product metadata populated directly
variant created if selected
no CatalogItem required
identifier behavior remains transitional as documented
```

## 3.3 Edit before save

### Test

Modify title, creator, publisher, format, price, or classification before save.

### Assertions

```text
edited values persist on product
variant receives correct operational defaults
no CatalogItem created
```

## 3.4 Duplicate detection

### Test

Import a candidate matching an existing product.

### Assertions

```text
existing product is found or duplicate warning appears
no duplicate product created unless staff confirms
no CatalogItem used for matching except transitional identifier paths documented for v0.04-2
```

## 3.5 External lookup product match

### Test

Run external lookup where a local product already exists for the ISBN.

### Assertions

```text
external_lookup_results.local_product_id (or equivalent) points to product
import creates/updates product metadata
no new CatalogItem created
preview shows product-target import
cover_image import attaches to product when URL present
```

---

## 4. Items Workspace Tests

## 4.1 Item index

### Test

Visit item index with products created directly.

### Assertions

```text
products appear (product-grain rows, not catalog-item-grain)
metadata displays correctly
variant summary displays correctly
product cover_image displays when attached
no CatalogItem dependency for query or display
index links use product_id (not catalog_item_id)
```

## 4.2 Item overview

### Test

Visit product/item overview via `product_id` query param.

### Assertions

```text
title/creator/publisher/format displayed from product
variant readiness matrix works
warnings work
history sections work
setup modals work
thumbnail from product cover_image only
```

## 4.2A Item show routing

### Test

Resolve item show via `product_id`, `product_variant_id`, and legacy `catalog_item_id` (if redirect retained).

### Assertions

```text
product_id loads correct item overview
product_variant_id loads correct item overview
catalog_item_id redirects to linked product (or 404 if unmapped) — no catalog-first requirement for new links
ItemsController does not require CatalogItem for product-backed items
```

## 4.2B Thumbnail resolver

### Test

Product with `cover_image` attached; product without cover (legacy catalog thumbnail may exist but must not be used).

### Assertions

```text
Items::ThumbnailResolver returns product cover_image
resolver does not read catalog_item.primary_thumbnail in active path
item index and overview render product thumbnail
ExternalCatalog cover import attaches to product cover_image
```

## 4.3 Variant operations drawer

### Test

Open variant operations drawer.

### Assertions

```text
variant label renders
product metadata renders
demand/action links still render
no CatalogItem dependency
```

---

## 5. POS Tests

## 5.1 POS line lookup by variant SKU

### Test

Scan or enter product variant SKU.

### Assertions

```text
variant found
line added
product metadata snapshot populated
variant SKU snapshot populated
transaction can complete
```

## 5.2 POS line lookup by product text search

### Test

Search by product title/name.

### Assertions

```text
product/variant candidate appears
staff can select variant
line added
transaction can complete
```

## 5.3 POS completion

### Test

Complete transaction with fused product model.

### Assertions

```text
transaction completes
tax/discount/tender behavior preserved
inventory posting still occurs when applicable
completed line snapshots are populated
```

## 5.4 POS void

### Test

Void completed sale.

### Assertions

```text
void succeeds
inventory reversal behavior preserved
snapshots remain historical
```

---

## 6. Inventory Tests

## 6.1 Inventory posting

### Test

Post inventory movement for variant whose product has no catalog item.

### Assertions

```text
Inventory::Post succeeds
ledger entry created
balance updated
product/variant snapshots or labels are populated
```

## 6.2 Manual adjustment

### Test

Create manual adjustment for variant.

### Assertions

```text
adjustment posts
balance changes
no CatalogItem dependency
```

---

## 7. Purchasing and Receiving Tests

## 7.1 Purchase order line add

### Test

Add product variant to purchase order.

### Assertions

```text
line created
variant linked
product metadata display works
vendor source behavior preserved
```

## 7.2 Receipt

### Test

Receive accepted quantity for purchase order line.

### Assertions

```text
receipt line created
accepted quantity posts to inventory
Inventory::Post still sole mutation path
product/variant labels display correctly
```

## 7.3 Return to vendor

### Test

Create RTV for variant.

### Assertions

```text
RTV line created
posting behavior preserved
no CatalogItem dependency
```

---

## 8. Buyback Tests

## 8.1 Buyback intake creates product

### Test

Enter item not already in catalog/product records.

### Assertions

```text
product created directly
catalog_item not created
used variant created or staged per existing workflow
buyback line snapshots populated
```

## 8.2 Buyback completion

### Test

Complete buyback session for accepted line.

### Assertions

```text
buyback posts inventory
created product/variant remain linked
stored value/cash behavior preserved
```

## 8.3 Existing product buyback

### Test

Buy back used copy for existing product.

### Assertions

```text
existing product found
used variant created or reused per current rules
no CatalogItem required
```

---

## 9. Reports Tests

## 9.1 Item drill-down

### Test

Open item/product drill-down report surfaces.

### Assertions

```text
product metadata displays
variant data displays
inventory/sales/purchasing summaries still work
no CatalogItem dependency
```

## 9.2 Operational reports

Run report smoke tests for:

```text
inventory value
purchasing summary
customer request queue
POS sales reports
buyback reports
```

### Assertions

```text
reports load
filters work
links resolve
no missing catalog_item association errors
```

---

## 10. Seed Tests

## 10.1 Seed validation

### Command

```bash
./dev/rails-docker bin/rails shelfstack:seeds:validate
```

### Assertions

```text
passes
seeded products have metadata directly
seeded variants link to products
no seeded product requires catalog item
```

## 10.2 Full seed

### Command

```bash
./dev/rails-docker bin/rails db:seed
```

### Assertions

```text
seed completes
demo data supports Items workspace
demo data supports POS smoke test
demo data supports inventory/purchasing smoke tests
```

## 10.3 Idempotent seed

### Test

Run seed twice.

### Assertions

```text
no duplicate products
no duplicate variants
stable keys remain stable
```

---

## 11. Static / Search-Based Checks

Run repository search for:

```text
CatalogItem
catalog_item
catalog_items
catalog_item_id
Items::IndexQuery
CatalogItemsController
Items::ThumbnailResolver
local_catalog_item_id
```

Focus review on files that still join or eager-load `catalog_items` for active staff paths.

Classify findings:

| Classification                                 |                  Allowed after v0.04-1? |
| ---------------------------------------------- | --------------------------------------: |
| Historical documentation                       |                                     yes |
| v0.03 spec reference                           |                                     yes |
| Migration/backfill code                        |                                     yes |
| v0.04-2 transitional identifier work           |                         yes, documented |
| Active product create/read/update runtime path |                                      no |
| Staff-facing active UI label                   |                                      no |
| New tests for v0.04 product flows              | no, unless explicitly testing migration |

Recommended search commands:

```bash
grep -R "CatalogItem" app test db lib docs | sort
grep -R "catalog_item" app test db lib docs | sort
grep -R "catalog_item_id" app test db lib docs | sort
```

---

## 12. Regression Test Matrix

| Area            | Minimum proof                        |
| --------------- | ------------------------------------ |
| Product model   | Direct metadata product valid        |
| Product variant | Variant linked to product            |
| Add Item        | Product created without catalog item |
| External lookup | Candidate imports to product         |
| Items workspace | Index, overview, routing, thumbnails load |
| POS             | Scan/search/add/complete works       |
| Inventory       | Posting works                        |
| Purchasing      | PO line add works                    |
| Receiving       | Accepted quantity posts              |
| Buybacks        | Intake and completion work           |
| Reports         | Operational reports load             |
| Seeds           | validate + seed pass                 |

---

## 13. Acceptance Scenarios

## Scenario 1 — Manual item creation

```text
Staff creates product manually
→ enters title, creator, publisher, format, list price
→ creates new variant
→ product appears in Items workspace
→ variant can be sold at POS
```

Pass criteria:

```text
No CatalogItem required.
```

## Scenario 2 — External catalog import

```text
Staff searches ISBNdb
→ selects candidate
→ product created with metadata
→ variant created
→ product overview displays metadata
→ local match uses product_id (not catalog_item_id)
```

Pass criteria:

```text
Metadata lives on Product.
No CatalogItem required.
Import audit references product where applicable.
```

## Scenario 2A — Item navigation

```text
Staff opens Items index
→ clicks product row
→ item overview loads via product_id
→ thumbnail displays from product cover_image
```

Pass criteria:

```text
No catalog_item_id required in URL for new navigation.
CatalogItemsController not used for staff item detail.
```

## Scenario 3 — Existing catalog backfill

```text
Existing catalog_item + product + variant
→ migration runs
→ product receives catalog metadata
→ variant remains linked
→ item overview and POS still work
```

Pass criteria:

```text
No operational data lost.
```

## Scenario 4 — Buyback-created item

```text
Staff enters used item in buyback
→ no existing product found
→ product created directly
→ used variant staged/created
→ buyback completes
→ inventory posts
```

Pass criteria:

```text
Buyback flow does not create or require CatalogItem.
```

## Scenario 5 — Purchasing/receiving

```text
Staff adds product variant to PO
→ receives accepted quantity
→ Inventory::Post updates stock
```

Pass criteria:

```text
PO and receipt lines remain variant-grain.
Product metadata displays without CatalogItem.
```

---

## 14. Completion Checklist

Mark v0.04-1 complete only when:

```text
[ ] Product metadata fields exist on products.
[ ] Existing products are backfilled.
[ ] Product model no longer requires catalog_item_id.
[ ] Add Item creates products directly.
[ ] External import creates products directly.
[ ] Items workspace reads product metadata directly.
[ ] Item index is product-grain; links use product_id.
[ ] Item show resolves via product_id (catalog_item_id redirect only if retained).
[ ] Product thumbnails use cover_image; no catalog thumbnail fallback in active paths.
[ ] Thumbnail backfill migration tested.
[ ] External lookup/import targets products (local_product_id or equivalent).
[ ] Product name rendering reads product metadata directly.
[ ] Product variants remain operational.
[ ] POS smoke tests pass.
[ ] Inventory smoke tests pass.
[ ] Purchasing/receiving smoke tests pass.
[ ] Buyback smoke tests pass.
[ ] Seed validation passes.
[ ] Full test suite passes or failures are documented.
[ ] Runtime CatalogItem references are removed or documented as transitional.
[ ] Staff-facing active UI no longer says Catalog Item.
[ ] docs/implementation/v0.04-1-completion.md is created.
```

---

## Known Follow-Up Work

These are expected after v0.04-1:

```text
v0.04-2 product_identifiers
v0.04-2 final variant SKU allocator decision
v0.04-3 product_groups
v0.04-4 variant-grain wire-through
v0.04-11 final documentation/schema cleanup
```
