# v0.04-4 Variant-Grain Wire-Through — Functional Specification

## Status

**In review** — implementation 2026-06-30. Merge after v0.04-2. See [v0.04-4-completion.md](../../implementation/v0.04-4-completion.md).

## Job

Finish the transition from catalog-item-centric operational paths to the fused **product + product_identifier + product_variant** model established in v0.04-1 and v0.04-2.

```text
Operational path (target):

  Product → ProductIdentifier → ProductVariant

Legacy shell (temporary):

  catalog_items — bibliographic/metadata bridge only; not operational owner
```

This is **not** the product-groups milestone (v0.04-3, deferred). It is **not** a second identifier milestone — v0.04-2 owns identifier ownership, segment policy (`201` / `211`), and mandatory scan resolution.

**Scope honesty:** v0.04-2 already ships POS/inventory/purchasing identifier lookup. v0.04-4 removes remaining catalog-item **assumptions** in UI, routing, imports, buyback FK writes, and cross-workspace joins — not a rewrite of lookup services.

---

## Purpose

After v0.04-2, staff and code should experience `/items` and operational workflows as **product-owned with variant-grain operations**. Catalog items may remain as a legacy metadata shell and admin surface until v0.04-11, but must not be the operational owner of identifiers, sellability, or intake resolution.

---

## Source documents

```text
docs/design/VERSION_0.04.md
docs/roadmap/v0.04-delivery-roadmap.md
docs/v0.04/README.md
docs/v0.04/v0.04-1-product-fusion/spec.md
docs/v0.04/v0.04-2-product-identifiers/spec.md
docs/implementation/v0.04-1-completion.md
docs/implementation/v0.04-2-completion.md
docs/handoff/phase-9-item-drill-down-contract.md
AGENTS.md
```

---

## Hard gates (do not reopen)

1. **Identifier ownership** stays on `product_identifiers`; do not reintroduce `catalog_item_identifiers` or catalog-item identifier CRUD as source of truth.
2. **Segment policy** unchanged: `201` product house, `211` generated variant SKUs.
3. **Historical snapshots** on POS/PO/receipt/buyback lines are not rewritten.
4. **`catalog_items` table** is not dropped in v0.04-4 (v0.04-11).
5. **POS/inventory/purchasing core lookup order** from v0.04-2 is not redesigned.

---

## Audit classification

Each remaining reference is assigned one action. The first implementation slice is to reconcile this table against `grep` and keep it current in the milestone branch.

| Action | Meaning |
| ------ | ------- |
| **Replace** | Retarget to product/product_variant in v0.04-4 |
| **Shim** | Keep redirect or bridge behavior temporarily |
| **Metadata admin** | Keep `/items/catalog_items` CRUD as legacy bibliographic shell |
| **Delete** | Dead or obsolete post–v0.04-2; remove in v0.04-4 |
| **Defer** | Document; address in v0.04-6 / v0.04-10 / v0.04-11 |
| **Preserve** | Snapshot/history; no mutation |

---

## Discovery audit — app runtime

Audit date: 2026-06-30 (re-run 2026-06-30 on implementation branch). Re-run before merge:

```bash
grep -R "catalog_item_id" app test db docs -n
grep -R "catalog_item" app/services app/controllers app/views app/presenters -n
grep -R "CatalogItem" app test -n
```

### Items workspace and routing

| Location | Current behavior | Action |
| -------- | ---------------- | ------ |
| `ItemsController#show` | `product_id` canonical; `catalog_item_id` redirects when product exists | **Shim** — keep redirect; emit `product_id` from all new links |
| `ItemPresenter#item_path_params` | Still emits `catalog_item_id` when no product | **Replace** — prefer `product_id`; catalog-only shell is edge case |
| `ItemPresenter.from_search_hit` | `"catalog_item_identifier"` hit type still handled | **Delete** — table dropped in v0.04-2 |
| `ItemPresenter.from_search_hit` | `"catalog_item"` hit type | **Replace** — resolve to product when linked |
| `Items::IndexQuery` | Browse/search already product/variant/identifier based | **Preserve** — verify only |
| `_catalog.html.erb` | Dual `setup_catalog_item` / `setup_product` display | **Replace** — product-owned copy; bibliographic fields from fused product or linked shell |
| `_overview.html.erb` | `catalog_item.blank?` branch | **Replace** — product-first lifecycle messaging |
| `items_helper` tab labels | `"catalog_items"` → "Item Details" | **Replace** — align labels with product ownership |
| `ItemLifecycleStatus` | Statuses for catalog-only without product | **Replace** — product-first warnings (missing product, missing identifiers, etc.) |
| `/items/catalog_items/*` CRUD | Legacy bibliographic admin; identifier actions delegate to product | **Metadata admin** — keep; URLs should return via `product_id` |
| `external_metadata/show` | Links with `catalog_item_id` | **Replace** — `product_id` |
| `catalog_items/edit_identifier` cancel link | `catalog_item_id` item path | **Replace** — `product_id` |

### Presenter URLs and item flow

| Location | Action |
| -------- | ------ |
| `ItemPresenter` edit/create product links using `catalog_item_id` | **Replace** |
| `ItemOperationsPresenter` edit catalog path | **Shim** — keep edit bibliographic metadata; return URL uses `product_id` |
| `ItemsHelper` placeholder images via `catalog_item_type` | **Replace** — use product `catalog_item_type` / fused metadata |

### Buyback

| Location | Current behavior | Action |
| -------- | ---------------- | ------ |
| `Buybacks::CreateIntakeItem` | Creates product-first; sets `line.catalog_item` from `product.catalog_item` | **Replace** — stop requiring catalog_item on line when product present |
| `Buybacks::CreateIntakeItem#create_product_for_legacy_catalog!` | Defined but uncalled | **Delete** |
| `Buybacks::SelectVariant` | Copies `catalog_item` onto line | **Replace** — product/variant only |
| `buyback_lines.catalog_item_id` | Intake hint FK | **Replace** writes — stop setting on new intake; preserve column |
| `buyback_lines.created_catalog_item_id` | Legacy provenance | **Replace** writes — use `created_product_id` only; preserve column |
| Buyback resolve UI `_resolve_results` | May use catalog language | **Replace** — product-first copy |

### External catalog and import

| Location | Action |
| -------- | ------ |
| `ExternalCatalog::ImportCandidate` — `catalog_item_id` param aliases `product_id` | **Replace** — `product_id` only in params/API |
| Import action types `create_catalog_item`, `link_existing_catalog_item` | **Replace** — rename staff-facing labels; product-first behavior (keep action keys or migrate with aliases) |
| `external_lookup/preview` duplicate links to `items_catalog_item_path` | **Replace** — `items_item_path(product_id: …)` |
| `ExternalCatalog::DuplicateDetector` Result `catalog_item` field | **Replace** — product-centric result; optional legacy field for display |
| `ExternalCatalog::LookupByIsbn` Outcome `catalog_item` | **Replace** — product-centric |
| `PersistLookupResult` `local_catalog_item` | **Shim** — resolve to product at boundary |
| `CatalogItemBuilder` / `StagedCatalogItemBuilder` | **Defer** product-only import path refinement to v0.04-11 unless blocking |

### Ingram import

| Location | Action |
| -------- | ------ |
| `IngramCatalogImport::Runner#upsert_catalog_item!` | **Shim** — still creates/updates metadata shell when needed; product is operational owner |
| `ProductResolver` via `catalog_item:` | **Replace** — prefer product-first resolution (partially done in v0.04-2) |
| Import outcomes `catalog_item_id` | **Replace** — report `product_id` as primary outcome id |

### Purchasing and orderability

| Location | Action |
| -------- | ------ |
| `Purchasing::TboQueueRowBuilder` joins `product → catalog_item` for format filter | **Replace** — filter on fused product `format_id` |
| `Purchasing::OrderEligibilityResolver#discontinued_catalog_item?` | **Replace** — `discontinued_product?` using fused `publication_status` on product |
| Warning keys `discontinued_catalog_item*` | **Replace** — product-centric message keys (alias old keys in reports if needed) |

### Customer demand (v0.03 tables)

| Location | Action |
| -------- | ------ |
| `CustomerRequests::StartFromItem` passes `catalog_item_id` | **Replace** — `product_id` |
| `CustomerRequests::MatchVariant` sets `catalog_item:` | **Replace** — product only |
| Full demand model | **Defer** to v0.04-6 |

### Product model and setup

| Location | Action |
| -------- | ------ |
| `Product` optional `catalog_item_id` FK | **Preserve** column; stop treating as required for sellability |
| `ProductsController` `catalog_item_id` on create from catalog shell | **Shim** — keep for legacy link; default new items product-first |
| `products/_form` catalog item select | **Metadata admin** — keep for explicit link; label as legacy bridge |
| `SkuGenerator.product_sku` reads via `catalog_item.primary_identifier` | **Replace** — `product.primary_identifier` / `products.sku` cache |
| `Product#apply_product_defaults` catalog-linked SKU path | **Replace** — `ProductIdentifierService` / transitional assigner |
| `Products::CopyCatalogMetadata` | **Shim** — keep for linked shell sync only |

### Reports and drill-down

| Location | Action |
| -------- | ------ |
| Customer request report link | Already `product_variant_id` | **Preserve** |
| `phase-9-item-drill-down-contract.md` documents `catalog_item_id` URLs | **Replace** doc — canonical `product_id` |
| Report snapshot field renames | **Defer** to v0.04-11 |

### Permissions

| Location | Action |
| -------- | ------ |
| `items.catalog_items.*` permission keys | **Preserve** for now — renaming keys is defer / separate cleanup |

### Dead code (delete in v0.04-4)

| Location | Reason |
| -------- | ------ |
| `ItemPresenter.from_search_hit` `"catalog_item_identifier"` branch | `catalog_item_identifiers` dropped |
| `Buybacks::CreateIntakeItem#create_product_for_legacy_catalog!` | Uncalled |
| Any remaining `CatalogIdentifierService` references | Removed in v0.04-2 — verify zero |

---

## In scope

1. **Canonical item routing** — `/items/item?product_id=` primary; legacy `catalog_item_id` redirects; new links emit `product_id` / `product_variant_id`.
2. **Item workspace finish** — presenter, setup tabs, modals, warnings, and copy reflect product ownership.
3. **Buyback intake/resolution** — product-first creates and line FK writes; remove dead paths.
4. **External catalog/import hygiene** — params, duplicate handling, and preview links prefer products.
5. **Purchasing/TBO joins** — remove catalog-item joins where product fields suffice.
6. **Report drill-down contract** — navigation URLs only (not snapshot renames).
7. **Verification rake** — `shelfstack:v0044:verify_wire_through` reports uncategorized runtime references.
8. **Documentation** — this bundle, completion note, README milestone table, roadmap DoD alignment.

---

## Out of scope

```text
Product groups (v0.04-3)
Demand foundation / allocations / sourcing (v0.04-6+)
PO/receiving quantity model redesign (v0.04-9)
Gift card / store credit 22X EAN (future)
Copy-level serial labels
Full catalog_items table drop (v0.04-11)
Full report/snapshot rename sweep (v0.04-11)
POS/inventory/purchasing lookup redesign (v0.04-2)
Café/menu lookup-code UI polish beyond v0.04-2 minimum (optional stretch)
Permission key rename items.catalog_items → items.products
```

---

## Implementation slices

### Slice 1 — Audit reconciliation

Re-run greps; update the audit table in this spec; open tracking issues per **Replace** row.

### Slice 2 — Routing and URL contract

- `ItemPresenter` path helpers emit `product_id`.
- Update external metadata, setup modals, catalog-item identifier cancel links, and item flow return params.
- Update [phase-9-item-drill-down-contract.md](../../handoff/phase-9-item-drill-down-contract.md).

### Slice 3 — Item workspace language

- `_catalog.html.erb`, `_overview.html.erb`, lifecycle status, helper labels.
- Remove dead search hit types.

### Slice 4 — Buyback cleanup

- Stop writing `catalog_item_id` / `created_catalog_item_id` on new intake when product is authoritative.
- Delete dead intake helpers; update resolve UI copy.

### Slice 5 — External catalog and Ingram param hygiene

- `ImportCandidate` product_id-only resolution path.
- Preview/duplicate links to product item page.
- Ingram outcome reporting prefers `product_id`.

### Slice 6 — Purchasing joins and warnings

- TBO queue format filter on product.
- Discontinued publication checks on fused product metadata.

### Slice 7 — Customer request bridges

- `StartFromItem` / `MatchVariant` product-centric params.

### Slice 8 — Tests and verification

- See [test-plan.md](test-plan.md).
- Add `lib/tasks/shelfstack/v0044_verify_wire_through.rake`.

---

## Definition of done

1. `/items` item show/browse behaves product-first; new links use `product_id` or `product_variant_id`.
2. Legacy `catalog_item_id` item URLs redirect to product when linked (shim preserved).
3. Product identifiers and variants are the clear operational units in item setup and warnings.
4. No new operational code depends on catalog-item identifier concepts.
5. Remaining `catalog_item_id` / `CatalogItem` runtime references are classified in this spec as **Shim**, **Metadata admin**, **Defer**, or **Preserve** — none uncategorized.
6. Buyback new intake/resolution is product-first; dead buyback catalog creation code removed.
7. External lookup/import duplicate and preview paths prefer products.
8. Phase 9 drill-down contract documents canonical URLs.
9. `shelfstack:v0044:verify_wire_through` passes.
10. Full test suite green; v0.04-4 docs complete; README marks v0.04-4 complete and names next milestone.

**Not required for v0.04-4:** zero `CatalogItem` references app-wide (target v0.04-11).

---

## Manual smoke

After implementation (recorded in completion note):

1. Open item by product from index — URL contains `product_id`.
2. Legacy bookmark with `catalog_item_id` redirects when product linked.
3. Add item / catalog intake — primary identifier creates `product_identifiers` row (not SKU cache only).
4. Fused product without `catalog_item` — bibliographic edit via `products#edit_metadata`.
5. External lookup duplicate → opens product item page.
6. Buyback intake new title → product created; line resolves without catalog-item creation.
7. TBO queue format filter still works via product format.
8. POS scan ISBN and variant SKU unchanged from v0.04-2 behavior.

---

## Next milestone

**v0.04-5 — Used variant rules** after v0.04-4 merge. **v0.04-3 — Product groups** remains deferred.
