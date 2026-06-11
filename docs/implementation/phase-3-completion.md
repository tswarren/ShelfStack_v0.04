# Phase 3 Completion Record

## Status

**Phase 3 (Catalog, Products, and Product Variants) is complete** as of 2025-06-10.

Phase 3 delivered the catalog metadata and sellable SKU foundation: formats, catalog items with identifiers, products, product variants, conditions, display locations, store display locations, vendors, identifier/SKU/name services, setup UI, permissions, audit events, and bookstore-oriented seeds.

Normative requirements remain in:

```text
docs/roadmap/phase-3-catalog-products-variants.md
docs/specifications/phase-3-catalog-products-variants-spec.md
docs/specifications/phase-3-data-model.md
docs/specifications/phase-3-test-plan.md
```

---

## Delivered Capabilities

### Database

Migration: `db/migrate/20250612120000_create_phase3_catalog_products_variants.rb`

| Table | Purpose |
| ----- | ------- |
| `formats` | Catalog format definitions (hardcover, ebook, etc.) |
| `catalog_items` | Metadata records with JSONB creator/subject fields |
| `catalog_item_identifiers` | External/local identifiers with primary-identifier partial unique index |
| `display_locations` | Global merchandising placement hierarchy |
| `store_display_locations` | Store activation of display locations |
| `products` | Store-facing product groupings with base SKU |
| `product_conditions` | Condition/special-state definitions for variant SKU suffixes |
| `product_variants` | Sellable SKUs with category, price, and inventory behavior |
| `vendors` | Basic supplier directory |

### Services

| Service | Responsibility |
| ------- | -------------- |
| `CatalogIdentifierService` | Normalize/validate identifiers, ISBN-10→13 conversion, local ID generation, primary identifier rules |
| `MetadataParser` | Parse semicolon-separated creators and subjects into JSONB |
| `SkuGenerator` | Product and variant SKU generation with condition/attribute suffix rules |
| `ProductNameRenderer` | Conservative product and variant name generation with override support |

Product cover images use Active Storage (`Product#cover_image`) and appear on the item overview, product index, and search results.

### Setup UI

Items workspace (`/items/*`):

- Unified search with lifecycle statuses
- Unified item detail (tabs: Overview, Catalog Details, Selling/SKUs, Display, Activity)
- Add Item wizard (identify → type → catalog → selling → default SKU)
- Item Details, Selling Setup, and Sellable SKUs CRUD (user-facing labels)

Setup workspace (`/setup/*`) — admin and reference data:

- **Foundation:** users, roles, stores, workstations, audit
- **Classification:** departments, categories, tax
- **Catalog and Items:** formats, product conditions, display locations, store display locations, vendors

Main navigation links **Items** and **Setup**.

### Permissions

Phase 3–related permissions seeded via `db/seeds/phase3_permissions.rb`:

- `items.access` plus `items.catalog_items.*`, `items.products.*`, and `items.product_variants.*`
- `setup.formats.*`, `setup.product_conditions.*`, `setup.display_locations.*`, `setup.store_display_locations.*`, and `setup.vendors.*`

Legacy `catalog.*` and `products.*` keys are deactivated on seed.

### Seeds

`db/seeds/phase3_catalog_products.rb` (idempotent):

- 10 example formats
- 11 product conditions
- 6 display locations with store activations
- 3 example vendors
- Demo catalog item (The Hobbit with ISBN-10→13 conversion), catalog-linked product + variant, gift card product, sideline with local identifier

---

## Verification

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails test
```

Expected: **136 tests, 0 failures** (model, service, authorization, and integration coverage for Phase 3).

---

## UX Alignment (Items Workspace)

Aligned with [ui-ux-concept.md](../specifications/ui-ux-concept.md):

### Navigation

- Main nav: **Items** + **Setup** (replacing separate Catalog, Products, and Admin labels)
- Header search wired to unified item search

### Items workspace (`/items/*`)

| Area | Route | Notes |
| ---- | ----- | ----- |
| Items home | `/items` | Search Items, Add Item, operational shortcuts |
| Unified search | `/items/search` | Lifecycle status badges on every result |
| Unified item detail | `/items/item?catalog_item_id=` or `?product_id=` | Overview, Catalog, Selling/SKUs, Display, Activity tabs |
| Item Details CRUD | `/items/catalog_items` | User-facing label: Item Details |
| Selling Setup CRUD | `/items/products` | User-facing label: Selling Setup |
| Sellable SKUs CRUD | `/items/product_variants` | User-facing label: Sellable SKUs |
| Add Item wizard | `/items/add_item/new` | Two-path flow: Catalog-linked or Non-catalog; optional search link on path choice |

#### Add Item workflows (refined)

Two user-facing paths:

| Path | Steps | Partial completion |
| ---- | ----- | ------------------ |
| **Catalog-linked item** | Item Details → Selling Setup → Sellable SKU | Done after Item Details → **Catalog Only** |
| **Non-catalog item** | Selling Setup → Sellable SKU | Done after Selling Setup → **Product Created** |

Services: `AddItem::InventoryBehaviorMapper`, `AddItem::DefaultSellingPrice`, `AddItem::ProductSkuGenerator`.

Legacy `/catalog/*` and `/products/*` URLs redirect to `/items/*`. Legacy catalog/products controllers and views were removed; only redirect routes remain.

### UX polish (Items workspace alignment)

Completed polish pass after the core UX-1 through UX-3B workstreams:

| Area | Change |
| ---- | ------ |
| Search results | Variant summary labels, price range, quick actions (View Item, Sell New, Edit Catalog, Edit SKUs, Add Used Copy) |
| Catalog forms | Creator and BISAC subject parse previews (server-rendered + live client preview) |
| Variant forms | Name preview with source line driven by product/condition/attributes |
| Add Item wizard | Catalog step reuses the full dynamic `catalog_items/_form` partial |
| Unified detail | Deeper breadcrumbs (catalog → product → variants); Display tab shows variant locations, store mappings, Setup vendor link |
| Items home | Operational raw-table shortcut cards removed |
| Cleanup | Removed legacy `catalog/` and `products/` controllers and views |

### Setup workspace (`/setup/*`)

Formats and Product Conditions moved from operational workspaces to Setup under **Catalog and Items**:

- Formats → `setup.formats.*`
- Product Conditions → `setup.product_conditions.*`
- Display Locations, Store Display Locations, Vendors (unchanged)

### Core abstractions

| Component | Path | Role |
| --------- | ---- | ---- |
| `Items::ItemPresenter` | `app/presenters/items/item_presenter.rb` | Canonical item view model for search, detail, wizard |
| `ItemLifecycleStatus` | `app/services/item_lifecycle_status.rb` | `basic` (search) and `full` (detail) lifecycle statuses |
| `ItemSearch` | `app/services/item_search.rb` | Unified search grouped by logical item |

### Permissions

Phase 3 permissions now use:

- `items.access` plus `items.catalog_items.*`, `items.products.*`, `items.product_variants.*`
- `setup.formats.*`, `setup.product_conditions.*`, plus existing setup merchandising keys

Legacy `catalog.*` and `products.*` keys are deactivated on seed.

---

## Known Gaps / Deferred Work

Per Phase 3 non-goals (unchanged):

- Inventory ledger, stock balances, receiving, POs, POS transactions
- Vendor-product sourcing, vendor costs, product price history
- Normalized contributors/subjects/publishers tables
- External bibliographic API integration
- Variant aliases
- Browser system tests in CI

---

## Next Priority

Phase 4 direction (see [roadmap.md](../roadmap.md)): **Inventory Foundation** is the recommended next phase.
