# v0.04-4 Variant-Grain Wire-Through — Test Plan

## Status

**Planned** — executable when v0.04-4 implementation begins.

---

## Prerequisites

- v0.04-2 merged (`product_identifiers`, scan paths, `catalog_item_identifiers` dropped)
- v0.04-1 complete (fused product metadata, product-first add item)

---

## Verification commands

```bash
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails shelfstack:seeds:validate
./dev/rails-docker bin/rails shelfstack:v0042:verify_product_identifiers
./dev/rails-docker bin/rails shelfstack:v0044:verify_wire_through
```

---

## Rake verification (new)

### `shelfstack:v0044:verify_wire_through`

Planned checks:

| Check | Pass condition |
| ----- | -------------- |
| Legacy identifier table references in app | Zero `catalog_item_identifiers` / `CatalogIdentifierService` in `app/` |
| Uncategorized runtime `CatalogItem` | Only allowlisted paths (catalog items admin, Ingram metadata upsert, optional FK includes) |
| New item URL generation | No new `catalog_item_id` link helpers outside allowlist |
| Buyback intake writes | New intake lines set `product_id` / `created_product_id`; do not set `created_catalog_item_id` |
| Audit table | Spec audit section present and dated |

---

## Unit and service tests

### Routing and presenter

| Test | Assert |
| ---- | ------ |
| `ItemPresenter` path params with product | Emits `product_id`, not `catalog_item_id` |
| `ItemsController#show` legacy URL | `catalog_item_id` redirects to `product_id` when product linked |
| `ItemPresenter.from_search_hit` | No `catalog_item_identifier` branch; catalog item hit resolves via product when linked |
| `Items::IndexQuery` | Unchanged product-first browse/search (regression) |

### SkuGenerator

| Test | Assert |
| ---- | ------ |
| `product_sku` with product identifiers | Uses `product.primary_identifier`, not `catalog_item.primary_identifier` |
| Catalog-linked product | Same result via product path |

### Buyback

| Test | Assert |
| ---- | ------ |
| `CreateIntakeItem` new title | Creates product; line has `product_id`; does not set `created_catalog_item_id` |
| `CreateIntakeItem` link existing | Resolves via `ProductIdentifierLookup`; no catalog item creation |
| Dead `create_product_for_legacy_catalog!` | Removed |

### External catalog

| Test | Assert |
| ---- | ------ |
| `ImportCandidate` target resolution | `product_id` param resolves product; `catalog_item_id` alias deprecated or removed |
| Duplicate detector | Returns product as primary match |
| Import flow integration | Preview duplicate link uses `product_id` item path |

### Purchasing

| Test | Assert |
| ---- | ------ |
| `TboQueueRowBuilder` format filter | Filters via product `format_id` without joining `catalog_items` |
| `OrderEligibilityResolver` discontinued | Uses product `publication_status`; warning keys product-centric |

### Customer requests

| Test | Assert |
| ---- | ------ |
| `StartFromItem` | Creates/links with `product_id` context, not `catalog_item_id` |

---

## Integration tests

| Area | Scenarios |
| ---- | --------- |
| Items item show | Open by `product_id`; tab navigation; setup modals return to product URL |
| Items legacy redirect | `catalog_item_id` bookmark redirects when product exists |
| Catalog item identifier admin | Add/edit identifier still works via product delegation (v0.04-2 regression) |
| Add item wizard | Product-first path end-to-end |
| Buyback staged workflow | Intake → resolve → proposal on product-first item |
| External lookup | Duplicate links to product item page |

---

## System / manual smoke

Document in completion note:

1. Item index → product detail URL shape
2. Legacy catalog_item bookmark redirect
3. Buyback intake without catalog item creation
4. External lookup import to existing product
5. TBO queue format filter
6. POS ISBN + variant SKU scan (v0.04-2 regression)

---

## Regression guards

Must remain green without behavior change:

- v0.04-2 identifier CRUD and house EAN generation
- POS / inventory / purchasing line lookup order
- Phase 9 report customer request link (`product_variant_id`)
- Buyback completion, void, inventory posting
- Ingram import product + identifier upsert

---

## Deferred test scope

Not v0.04-4:

- Report snapshot column renames
- `catalog_items` table drop
- Product groups
- Demand line model (v0.04-6)
- Permission key rename

---

## Definition of done (testing)

1. New/updated tests cover routing, buyback intake, import resolution, and purchasing join changes.
2. `shelfstack:v0044:verify_wire_through` implemented and passes in CI.
3. Full suite green on merge commit.
4. Manual smoke checklist recorded in [v0.04-4-completion.md](../../implementation/v0.04-4-completion.md).
