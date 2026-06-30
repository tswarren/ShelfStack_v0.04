# v0.04-4 Variant-Grain Wire-Through — Data Model Notes

## Status

**Planned** — companion to [spec.md](spec.md).

---

## Canonical operational grain

| Grain | Table | Role after v0.04-4 |
| ----- | ----- | ------------------ |
| Product metadata + fused bibliographic fields | `products` | Operational owner for item identity, classification defaults, list price |
| Product-level barcodes | `product_identifiers` | Source of truth (v0.04-2) |
| Sellable SKU | `product_variants` | Operational unit for price, tax/classification, inventory, POS, purchasing lines |
| Variant POS shortcuts | `product_variant_lookup_codes` | Optional (v0.04-2) |
| Legacy bibliographic shell | `catalog_items` | **Metadata bridge only** — optional FK from `products.catalog_item_id` |

```text
Product (required for sellability)
  ├── product_identifiers (0..n)
  └── product_variants (1..n for sellable product)

catalog_items (optional)
  └── linked products (0..n) — legacy; prefer single product link or none
```

---

## Columns unchanged in v0.04-4

v0.04-4 is primarily a **behavior and join cleanup** milestone. Do not drop these without v0.04-11 scope:

| Column | Table | v0.04-4 behavior |
| ------ | ----- | ---------------- |
| `products.catalog_item_id` | `products` | Nullable FK preserved; new product-first items may leave null |
| `buyback_lines.catalog_item_id` | `buyback_lines` | Stop writing on new intake when `product_id` set; column retained |
| `buyback_lines.created_catalog_item_id` | `buyback_lines` | Stop writing; use `created_product_id`; column retained |
| `buyback_lines.product_id` | `buyback_lines` | Required operational FK for resolved lines |
| POS/PO/receipt snapshot columns | various | **Preserve** — no renames in v0.04-4 |

Future v0.04-11 may drop `catalog_items` and nullable FKs after satellite cleanup.

---

## URL / routing contract

Canonical item detail URLs:

```text
/items/item?product_id=:id&tab=:tab
/items/item?product_variant_id=:id&tab=:tab
```

Legacy shim (keep in v0.04-4):

```text
/items/item?catalog_item_id=:id&tab=:tab
  → 302 to product_id when an active linked product exists
  → catalog-only shell page when no product (rare; metadata admin edge case)
```

Report drill-down (update handoff contract):

```text
Prefer: product_variant_id (variant-scoped reports)
Prefer: product_id (product-scoped reports)
Avoid new links: catalog_item_id
```

---

## Identifier and SKU resolution (unchanged)

v0.04-4 does **not** change lookup order from v0.04-2:

```text
1. product_variants.sku
2. product_variant_lookup_codes
3. product_identifiers (active)
4. ISBN cross-form candidates
5. products.sku (legacy fallback)
```

Replace code that still reads identifiers via `catalog_item.primary_identifier` with `product.primary_identifier` (see `CatalogItem#primary_identifier` bridge delegating to product — remove callers, not necessarily the bridge method yet).

---

## Services to retarget

| Service | Change |
| ------- | ------ |
| `SkuGenerator.product_sku` | Use `product.primary_identifier` / `products.sku` |
| `Purchasing::TboQueueRowBuilder` | Format filter via `products.format_id` |
| `Purchasing::OrderEligibilityResolver` | Discontinued check on product fused `publication_status` |
| `CustomerRequests::StartFromItem` | Pass `product_id` not `catalog_item_id` |
| `ExternalCatalog::ImportCandidate` | Resolve target by `product_id` only |
| `Buybacks::CreateIntakeItem` | Product-first line updates; delete dead catalog helpers |

---

## Metadata sync (keep as shim)

These remain valid while `catalog_item_id` FK exists:

| Service | Role |
| ------- | ---- |
| `Products::CopyCatalogMetadata` | One-way sync shell → product on link |
| `Products::CopyCategorizationsFromCatalogItem` | Store category / BISAC bridge |
| `CatalogItemBisacSync` / `ProductBisacSync` | BISAC picker sync |
| `CatalogItemStoreCategorySync` | Store category on catalog shell |

v0.04-4 may update callers to prefer product as sync target where both exist.

---

## Verification output (planned rake)

`shelfstack:v0044:verify_wire_through` should fail when:

- Uncategorized `CatalogItem` loads outside allowlist (metadata admin controllers, optional FK eager loads, Ingram metadata upsert).
- App views generate new `items_item_path(catalog_item_id: …)` except documented shims.
- Buyback intake writes `created_catalog_item_id` on new lines.
- Dead reference patterns remain (`catalog_item_identifier`, `CatalogIdentifierService`).

Allowlist file: maintain in rake task comments or `docs/v0.04/v0.04-4-variant-grain-wire-through/spec.md` audit table.

---

## Relationship to v0.04-3 and v0.04-11

| Milestone | Relationship |
| --------- | -------------- |
| v0.04-3 Product groups | Deferred; no schema in v0.04-4 |
| v0.04-5 Used variant rules | Builds on product-first buyback/intake from v0.04-4 |
| v0.04-6 Demand foundation | Customer request bridges cleaned in v0.04-4; model replacement deferred |
| v0.04-11 Doc/schema cleanup | Full `catalog_items` drop, permission renames, report snapshot renames |
