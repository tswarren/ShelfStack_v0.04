# v0.04-1 Product Fusion — Functional Specification

## Purpose

This milestone collapses the v0.03 runtime separation between `catalog_items` and `products`.

After v0.04-1, ShelfStack should treat **Product** as the primary record for a specific commercial item, edition, release, manufactured item, café item, service, or store-created product.

The application should no longer require a `CatalogItem` record in normal create/read/update workflows.

```text
v0.03:
Catalog Item → Product → Product Variant

v0.04 target:
Optional product_group → Product → Product Variant
```

This milestone prepares the item identity layer for v0.04-2 Product Identifiers.

---

## Source Documents

Read before implementation:

```text
README.md
docs/design/VERSION_0.04.md
docs/roadmap/v0.04-delivery-roadmap.md
docs/v0.04/README.md
docs/specifications/phase-3-catalog-products-variants-spec.md
docs/specifications/phase-3-data-model.md
docs/implementation-guide.md
AGENTS.md
```

---

## Scope

### In scope

v0.04-1 includes:

1. Moving catalog metadata fields onto `products`.
2. Removing runtime create/read/update dependency on `catalog_items`.
3. Updating `Product` model behavior so a product represents a specific commercial item.
4. Updating Add Item flows to create products directly.
5. Updating external catalog lookup/import flows to populate products directly.
6. Updating item presenters, index/search display, and product name rendering.
7. Updating seeds, fixtures, factories, and test helpers.
8. Preserving existing product variant operational behavior.
9. Preserving existing inventory, POS, purchasing, receiving, buyback, customer demand, and reporting behavior as much as possible.
10. Marking legacy `CatalogItem` code paths as removed, inactive, or explicitly transitional.

### Out of scope

v0.04-1 does **not** implement the full identifier redesign.

Specifically, this milestone does **not** finish:

1. `product_identifiers`.
2. Identifier `validation_family`.
3. ISBN-10 / ISBN-13 bidirectional alternate service changes.
4. Final House EAN-13 allocator.
5. Final system-assigned variant SKU allocator decision.
6. Product groups / works.
7. Demand lines.
8. Allocations.
9. Sourcing runs, attempts, or vendor responses.
10. PO/receiving quantity lifecycle changes.

Those belong to later milestones.

---

## Important Boundary: Identifiers

v0.04-2 owns the full transition from:

```text
catalog_item_identifiers → product_identifiers
```

However, v0.04-1 must not make product fusion impossible.

Until v0.04-2 lands, v0.04-1 may use transitional fields such as `products.sku` or another explicitly named cached primary identifier field to preserve lookup, import, and display behavior.

Rules:

1. Do not introduce new business rules that treat `products.sku` as the canonical product identifier.
2. Do not derive variant SKUs from product identifiers.
3. Do not expand the old `catalog_item_identifiers` model for new feature work.
4. Preserve enough identifier information for v0.04-2 to create `product_identifiers`.
5. If physical removal of `catalog_item_identifiers` depends on v0.04-2, document the temporary dependency clearly.

---

## Domain Rules

### Product

A product is ShelfStack’s record for a specific commercial item.

Examples:

```text
Hardcover book ISBN = one product
Paperback book ISBN = another product
CD UPC release = one product
Vinyl UPC release = another product
DVD edition UPC = one product
Gift UPC = one product
Café drink = one product
Service item = one product
```

A product is not a title-level abstraction that spans multiple ISBNs, releases, or formats.

### Product Variant

A product variant remains the operational grain for:

```text
POS lines
inventory ledger entries
stock balances
purchase order lines
receipt lines
customer demand
reservations / allocations
buybacks
pricing behavior
tax/classification behavior
vendor orderability
```

v0.04-1 must preserve this.

### Product Group

Product groups are not part of v0.04-1 implementation.

Do not add `product_groups` in this milestone unless the milestone is explicitly expanded.

---

## Functional Requirements

## 1. Product Records

### Requirement

Products must be able to store the metadata previously stored on catalog items.

Product-level metadata should include, as applicable:

```text
title
subtitle
creator / contributor display
creator / contributor structured data
publisher / manufacturer display
publisher / manufacturer structured data
format
edition statement
publication or release date
series display data
series structured data
subjects / genres / themes / BISAC data
target audience data
access restriction data
description
dimensions
weight
duration
page count
language
digital / physical indicators
source
needs_review
active
```

### Expected behavior

Staff and services should be able to create a product directly with metadata, without first creating a catalog item.

---

## 2. Add Item Wizard

### Requirement

The Add Item wizard must create products directly.

### Current v0.03 behavior

The wizard may currently create or select a catalog item, then create a product and variant beneath it.

### v0.04-1 behavior

The wizard should create or update:

```text
Product
→ Product Variant
```

without requiring:

```text
CatalogItem
```

### Requirements

1. Staff can search external catalog data.
2. Staff can preview external catalog data.
3. Staff can create a product from selected metadata.
4. Staff can create an initial product variant.
5. Staff can edit or override product fields before save.
6. The created product carries metadata directly.
7. The created variant remains linked to the product.
8. The flow works for book and non-book product types.

---

## 3. External Catalog Lookup and Import

### Requirement

External catalog lookup/import services must populate `products` directly.

Affected areas include:

```text
ExternalCatalog::*
IngramCatalogImport::*
AddItem::*
```

### Requirements

1. External candidate data maps to product fields, not catalog item fields.
2. Import preview displays product metadata.
3. Import save creates or updates products.
4. Existing duplicate detection should be preserved as much as possible.
5. Identifier-specific matching may remain transitional until v0.04-2.
6. Imported metadata should preserve source/audit information where existing code already does so.

### Boundary

Identifier normalization and final product identifier persistence are v0.04-2 responsibilities.

---

## 4. Product Name Rendering

### Requirement

Product display names should render from product fields directly.

Affected area:

```text
ProductNameRenderer
```

### Requirements

1. Product name no longer depends on `catalog_item.title`.
2. Product name should use product metadata and overrides.
3. Variant name rendering should still use product name plus variant attributes/condition where applicable.
4. Existing snapshots on completed documents should not be rewritten.

---

## 5. Items Workspace

### Requirement

The Items workspace should display product metadata directly.

Affected areas include:

```text
Items::ItemPresenter
Items::ItemOverviewPresenter
Items::IndexQuery
Items::VariantOperationalSnapshot
Items::ThumbnailResolver
Items index/search views
item overview
item setup modals
variant operations drawer labels
ItemsController (item show resolution)
CatalogItemsController (retire or redirect)
```

### Requirements

1. Item overview reads product metadata directly.
2. Item index/search reads product metadata directly.
3. Variant matrix/readiness display continues to work.
4. Operational warnings continue to work.
5. Existing variant operations drawer continues to work.
6. Links, labels, breadcrumbs, and headings should use Product terminology where possible.
7. Any remaining “Catalog Item” terminology should be removed from active staff-facing v0.04 paths.

---

## 5A. Items Routing and Navigation

### Requirement

The Items workspace must treat **Product** as the primary navigational grain for item detail, not Catalog Item.

### Current v0.03 behavior

Item show resolves through:

```text
/items/item?catalog_item_id=…   (common path)
/items/item?product_id=…
/items/item?product_variant_id=…
```

The index (`Items::IndexQuery`) is catalog-item-centric: rows group by catalog item, and many links pass `catalog_item_id`.

Setup/admin CRUD for catalog metadata lives under nested `resources :catalog_items` (identifier CRUD, inactivate, local identifier generation).

### v0.04-1 behavior

1. **Item show** should prefer `product_id` (or `product_variant_id`) as the canonical query param for staff navigation.
2. **Item index** should list/search **products** (with variant summaries), not catalog items.
3. Links from index, reports, and operational screens should pass `product_id` (or variant id where variant-specific).
4. `catalog_item_id` query param may remain temporarily as a **redirect** to the linked product for bookmark compatibility during v0.04-1, but must not be required for new flows.
5. Retire or redirect `CatalogItemsController` CRUD routes; product metadata editing belongs on product/item setup paths.
6. Identifier CRUD routes under `catalog_items` remain **transitional** until v0.04-2 moves them to product-scoped identifier endpoints — document any retained routes explicitly.

### Affected routes (review list)

```text
GET  /items/item                    (ItemsController#show)
GET  /items                         (Items::IndexController)
resources :catalog_items             (CatalogItemsController — retire/redirect)
GET  /items/add_item                (AddItem — product-first output)
POST /items/external_lookup*        (product-target imports)
```

### Definition of done (routing)

1. New item links use `product_id`.
2. Item index does not require `CatalogItem` for display or search.
3. No active staff workflow **creates** catalog items.
4. Remaining `catalog_item_id` params/routes are documented as transitional.

---

## 5B. Thumbnails and Cover Images

### Requirement

Product imagery must not depend on `CatalogItem#primary_thumbnail` in active runtime paths.

### Current v0.03 behavior

* `CatalogItem` has `has_one_attached :primary_thumbnail` (Phase 8.5-4).
* `Product` may have `cover_image` (Active Storage).
* `Items::ThumbnailResolver` prefers `product.cover_image`, then falls back to `catalog_item.primary_thumbnail`.

### v0.04-1 behavior

1. **Canonical attachment:** `Product#cover_image` (already on `products`). Backfill catalog `primary_thumbnail` blobs onto product `cover_image` where mapped.
2. Update `Items::ThumbnailResolver` to read product `cover_image` only (no `catalog_item` fallback in active paths).
3. Update item index and overview to eager-load product thumbnail attachments directly.
4. Preserve validation rules (content type, max size) when moving attachment.
5. Backfill: copy catalog item thumbnail blobs to the linked product where a single clear product mapping exists; mark `needs_review` or leave unattached when ambiguous (multiple products per catalog item).

### Boundary

Thumbnail display on completed historical documents does not need blob migration if snapshots already captured URLs/metadata elsewhere — focus on active Items workspace and Add Item preview.

### BISAC / store category sync

Retarget or rename catalog-item-scoped sync services for product-scoped metadata:

```text
CatalogItemBisacSync        → product-scoped BISAC sync (or inline on product save)
CatalogItemStoreCategorySync → product-scoped store category sync
```

Do not add new catalog-item sync behavior.

---

## 6. Inventory / POS / Purchasing / Receiving Preservation

### Requirement

Operational workflows must continue to work at product variant grain.

v0.04-1 should preserve behavior for:

```text
POS lookup and line creation
POS completion / void
Inventory::Post
inventory balances
manual adjustments
purchase order lines
receipt lines
returns to vendor
buyback intake and completion
stored value
operational reports
```

### Requirements

1. Existing `product_variants.product_id` references remain valid.
2. Existing product variant records remain attached to products.
3. Existing snapshots remain historically valid.
4. Existing completed transactions and documents are not rewritten.
5. Existing operational reports should not fail because `CatalogItem` is absent from active product flows.
6. Where a report previously displayed catalog item fields, it should now read equivalent product fields.

---

## 7. Buybacks

### Requirement

Buyback intake and used variant creation must continue to work.

### Requirements

1. Buyback provisional capture can resolve or create product metadata without requiring catalog item creation.
2. Buyback-created products carry metadata directly.
3. Buyback-created variants remain linked to products.
4. Buyback completion continues to post inventory through existing posting services.
5. Historical buyback snapshots remain valid.
6. Any remaining `created_catalog_item_id` or `catalog_item_id` usage should be either removed, migrated, or explicitly documented as transitional until later cleanup.

---

## 8. Seeds

### Requirement

Seed data must create products directly.

### Requirements

1. Product seed helpers do not require catalog items.
2. Seeded products include relevant metadata directly.
3. Seeded variants remain attached to products.
4. Seed validation passes.
5. BISAC / category / format seed behavior remains compatible.
6. Existing development demo data remains useful for item, inventory, POS, purchasing, and reporting workflows.

---

## 9. Authorization and Audit

### Requirement

No permissions or audit coverage should be lost.

### Requirements

1. Product create/update/delete or deactivate events remain permission-controlled.
2. Product metadata changes should be audited where comparable catalog item changes were audited.
3. Add Item and import flows continue to emit audit events where they did previously.
4. Retired catalog item events should not be used by new product flows.
5. New audit event names should prefer product vocabulary.

---

## 10. Staff-Facing Language

### Requirement

Active v0.04 staff-facing screens should use Product language.

### Replace where user-visible:

```text
Catalog Item
Catalog item
catalog item
```

with suitable Product-centered terms, unless referencing historical docs or legacy implementation.

Preferred language:

```text
Product
Item
Product metadata
Product identifier
Variant
SKU
```

Use “Item” where the UI needs a staff-friendly umbrella term.

---

## Migration / Cutover Strategy

Because ShelfStack is pre-production, v0.04 may use destructive schema changes.

**Data strategy (from [v0.04-0 completion](../../implementation/v0.04-0-completion.md)):** use **reseed**, not a one-time production migration script. After destructive migrations during development:

```bash
./dev/rails-docker bin/rails db:drop db:create db:migrate db:seed
./dev/rails-docker bin/rails shelfstack:seeds:validate
```

Backfill migrations remain useful for verifying metadata copy logic and for environments that keep data between iterations, but authoritative dev/demo recovery is reseed.

Recommended implementation posture for v0.04-1:

1. Add product metadata fields (and product thumbnail attachment if not already present).
2. Backfill products from linked catalog items (metadata + thumbnails where mapped).
3. Update runtime code to read/write product fields.
4. Update Add Item, import, Items index/routing, and thumbnail resolver.
5. Update tests and seeds.
6. Remove runtime `CatalogItem` dependency.
7. **Default: Path B** — quarantine `catalog_items` until v0.04-2 identifier migration (see data-model). Do not drop `catalog_items` in v0.04-1 unless identifier/import FK work is completed in the same branch.
8. Record any remaining schema FK to `catalog_items` as transitional, not runtime dependencies.

---

## Definition of Done

v0.04-1 is complete when:

1. Staff can create a product with metadata directly.
2. Add Item creates products with metadata directly.
3. External catalog lookup/import creates or updates products directly.
4. Product show/index/overview pages display product metadata without requiring `catalog_items`.
5. Product variants remain operational and attached to products.
6. POS can still scan/search and add product variants.
7. Inventory posting still works.
8. Purchasing and receiving still work for product variant lines.
9. Buyback-created products and variants still work.
10. Seeds and seed validation pass.
11. Tests for item creation and external import pass on the new model.
12. No active create/read/update runtime path requires `CatalogItem`.
13. Item index and item show navigation use product (or variant) as primary grain; `catalog_item_id` is not required for new links.
14. Product thumbnails resolve without reading `CatalogItem#primary_thumbnail` in active paths.
15. Any remaining catalog-item tables, columns, or code references are documented as transitional and assigned to v0.04-2, v0.04-4, or v0.04-11.
16. Documentation is updated with a completion note.

---

## Non-Goals

Do not implement these in v0.04-1:

```text
product_identifiers final table
identifier validation families
ISBN alternate service rewrite
house EAN-13 allocator
final variant SKU allocator decision
product_groups
demand_lines
demand_allocations
sourcing_runs
vendor_responses
PO/receiving quantity lifecycle expansion
full UI consistency sweep
```

---

## Implementation Notes

### Recommended service review list

```text
AddItem::*
ExternalCatalog::*
IngramCatalogImport::*
ProductNameRenderer
Items::ItemPresenter
Items::ItemOverviewPresenter
Items::IndexQuery
Items::ThumbnailResolver
Items::OperationalWarningBuilder
Items::VariantOperationalSnapshot
CatalogItemBisacSync (retarget to product)
CatalogItemStoreCategorySync (retarget to product)
Buybacks::FindOrCreateGradedUsedVariant
Buybacks::CreateIntakeItem
Buybacks::ResolveItem
Inventory::TrackingResolver
Inventory::Eligibility
Purchasing lookup / line add services
Pos::LineLookup
Reports item drill-down helpers
ItemsController
CatalogItemsController (retire/redirect)
Items::SetupModalsController
```

### Recommended model review list

```text
CatalogItem
CatalogItemIdentifier
Product
ProductVariant
ProductVendor
ProductVariantVendor
BuybackLine
CustomerRequestLine
PurchaseOrderLine
ReceiptLine
Inventory ledger / balance models
POS transaction line models
```

### Runtime dependency rule

Search for runtime references to:

```text
CatalogItem
catalog_item
catalog_items
catalog_item_id
```

Classify each as:

```text
remove in v0.04-1
rewrite to product
transitional until v0.04-2 identifiers
transitional until v0.04-4 wire-through
historical/test/doc only
```

v0.04-1 should remove or rewrite all create/read/update runtime dependencies. Transitional references must be documented.
