# Phase 3 Completion Record

## Status

**Phase 3 (Catalog, Products, and Product Variants) is complete** as of 2026-06-10.

Manual QA sign-off: all Phase 3 manual test scenarios passed (catalog identifiers, Add Item wizard, products/variants, classification setup, Ingram import smoke paths, permissions, and audit timelines).

Phase 3 delivered the catalog metadata and sellable SKU foundation: formats, catalog items with identifiers, products, product variants, conditions, display locations, store display locations, vendors, subdepartments and store categories (classification target), identifier/SKU/name services, setup UI, permissions, audit events, and bookstore-oriented seeds.

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
| `product_variants` | Sellable SKUs with subdepartment, price, and inventory behavior |
| `vendors` | Basic supplier directory |

### Services

| Service | Responsibility |
| ------- | -------------- |
| `CatalogIdentifierService` | Normalize/validate identifiers, ISBN-10→13 conversion, local ID generation, primary identifier rules |
| `MetadataParser` | Parse semicolon-separated creators and subjects into JSONB |
| `SkuGenerator` | Product and variant SKU generation with condition/attribute suffix rules |
| `ProductNameRenderer` | Conservative product and variant name generation with override support |
| `SubDepartmentSuggestion`, `StoreCategoryDefaults`, `VariantClassificationSetup` | Subdepartment and display-location defaults from product, store category, or condition |
| `TreeOrdering`, `SubDepartmentIndexTree` | Hierarchical index and select-list ordering for setup screens |

Product cover images use Active Storage (`Product#cover_image`) and appear on the item overview, product index, and search results. Cover images attach during the Add Item selling-setup step and on product edit.

### Setup UI

Items workspace (`/items/*`):

- Unified search with lifecycle statuses
- Unified item detail (tabs: Overview, Operations, Item setup, Activity)
- Add Item wizard (identify → type → catalog → selling → default SKU)
- Item Details, Selling Setup, and Sellable SKUs CRUD (user-facing labels)

Setup workspace (`/setup/*`) — admin and reference data:

- **Foundation:** users, roles, stores, workstations, audit
- **Classification:** departments, subdepartments, store categories, tax (legacy categories retained for reference)
- **Catalog and Items:** formats, product conditions, display locations, store display locations, vendors, BISAC subjects

Setup index pages and related select lists use hierarchical tree ordering for display locations, store categories, and subdepartments (department → subdepartment).

### Permissions

Phase 3–related permissions seeded via `db/seeds/phase3_permissions.rb`:

- `items.access` plus `items.catalog_items.*`, `items.products.*`, and `items.product_variants.*`
- `items.ingram_import.run`
- `setup.formats.*`, `setup.product_conditions.*`, `setup.display_locations.*`, `setup.store_display_locations.*`, `setup.vendors.*`, `setup.sub_departments.*`, `setup.category_schemes.*`

Legacy `catalog.*` and `products.*` keys are deactivated on seed.

### Seeds

`db/seeds/phase3_catalog_products.rb` (idempotent):

- 10 example formats
- 11 product conditions
- 6 display locations with store activations
- 3 example vendors
- Demo catalog item (The Hobbit with ISBN-10→13 conversion), catalog-linked product + variant, gift card product, sideline with local identifier

Reference trees (`db/seeds/phase3b_reference_trees.rb`, `Seeds::CsvClassificationImporter`):

- ~57 display locations (hierarchy from `display_locations.csv`)
- ~151 store category nodes with default subdepartment and display location (`store_categories.csv`)
- ~35 subdepartments (`sub_departments.csv`)
- Phase 2 tax/department data from CSV (`tax_categories.csv`, `departments.csv`, `store_tax_rates.csv`, `store_tax_mappings.csv`)
- Optional BISAC import from `bisac.csv` (see [csv-seeds.md](csv-seeds.md))

Validate CSVs before seeding: `./dev/rails-docker bin/rails shelfstack:seeds:validate`

---

## Verification

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails test
```

Expected: full Minitest suite passes (280+ tests; model, service, authorization, and integration coverage through Phase 3 and classification migration).

Manual QA (2026-06-10): passed — catalog identifiers (including invalid ISBN-13 warnings), Add Item wizard (catalog-linked and non-catalog), product/variant CRUD, cover image upload, classification setup trees, permissions, seeds idempotency, and Phase 1–2 regression smoke.

---

## UX Alignment (Items Workspace)

Aligned with [ui-ux-concept.md](../specifications/ui-ux-concept.md):

### Navigation

- Main nav: **Items** + **Setup** (replacing separate Catalog, Products, and Admin labels)
- Header search wired to Items index at `/items`

### Items workspace (`/items/*`)

| Area | Route | Notes |
| ---- | ----- | ----- |
| Items index | `/items` | Browse + keyword search, filters, pagination; Add Item and Ingram Import toolbar |
| Legacy search redirect | `/items/search` | Redirects to `/items` with preserved params |
| Unified item detail | `/items/item?catalog_item_id=` or `?product_id=` | Overview, Operations, Item setup, Activity tabs |
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

#### Form layout standard

Setup and Items forms use shared partials under `app/views/shared/forms/` (`_page_header`, `_section`, `_field`, `_checkbox`, `_errors`) with CSS width modifiers (`ss-form--standard`, `ss-form--wide`). Stimulus preview controllers: `department-number-preview`, `basis-points-preview`, `tax-mapping-preview`, `variant-preview`. See `docs/specifications/ui-ux-concept.md` §29.

Legacy `/catalog/*` and `/products/*` URLs redirect to `/items/*`. Legacy catalog/products controllers and views were removed; only redirect routes remain.

### Items Index v1 (Phase 3.5)

Delivered 2026-06:

- `/items` replaces card launcher with paginated browse + keyword search
- Filters: format, department, subdepartment, store category, include inactive
- Row grain: logical item via `Items::ItemPresenter` (catalog-linked or non-catalog product)
- Service: `Items::IndexQuery`; `ItemSearch` delegates for backward compatibility
- Deferred: per-field search UI, column sorting, full-text search, inventory columns

### UX polish (Items workspace alignment)

Completed polish pass after the core UX-1 through UX-3B workstreams:

| Area | Change |
| ---- | ------ |
| Search results | Variant summary labels, price range, quick actions (View Item, Sell New, Edit Catalog, Edit SKUs, Add Used Copy) |
| Catalog forms | Creator and BISAC subject parse previews (server-rendered + live client preview) |
| Variant forms | Name preview with source line driven by product/condition/attributes |
| Add Item wizard | Catalog step reuses the full dynamic `catalog_items/_form` partial |
| Item edit subflows | Product and variant edit/create from the unified item page reuse shared form partials with `return_to=item`; save/cancel return to the correct item tab |
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
| `ItemSearch` | `app/services/item_search.rb` | Thin wrapper over `Items::IndexQuery` for keyword-only callers |
| `Items::IndexQuery` | `app/services/items/index_query.rb` | Browse, search, filters, pagination for Items index |

### Permissions

Phase 3 permissions now use:

- `items.access` plus `items.catalog_items.*`, `items.products.*`, `items.product_variants.*`
- `items.ingram_import.run` for Ingram spreadsheet import
- `setup.formats.*`, `setup.product_conditions.*`, plus existing setup merchandising keys

Legacy `catalog.*` and `products.*` keys are deactivated on seed.

### Ingram catalog import

Spreadsheet import for Ingram vendor lists (`docs/specifications/ingram-catalog-import-spec.md`):

- Service: `IngramCatalogImport::Runner` with parser, identifier/product/variant resolvers
- UI: Items → Ingram Import (upload, preview, required default category, run)
- Upserts catalog items and products by EAN/Product Code; creates new-condition variants only when missing
- Existing variants are matched and never overwritten by default

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

**Phase 4: Inventory Foundation** per [roadmap.md](../roadmap.md) — recommended because purchasing, receiving, and POS depend on reliable stock movement behavior.
