# v0.04-2 Product Identifiers — Functional Specification

## Status

**Planned**

## Job

Replace legacy `catalog_item_identifiers` with product-scoped `product_identifiers`, introduce validation families, complete the v0.04 identifier/SKU split, and establish working scan resolution for POS and imports.

v0.04-2 finishes the identifier transition started in v0.04-1:

```text
v0.04-1:
  catalog_items retained as Path B legacy bridge
  catalog_item_identifiers retained for transitional lookup/admin
  products hold fused catalog metadata

v0.04-2:
  products → product_identifiers
  product_variants → system-assigned variant SKUs (segment 211)
  product_variants → optional short manual lookup codes (thin slice)
  catalog_item_identifiers removed
  CatalogIdentifierService replaced by ProductIdentifierService
  catalog_items retained (quarantined legacy metadata shell only)
```

**Scope honesty:** v0.04-2 delivers **product metadata identifier ownership + scan resolution complete**. It is **not** “SKU invariant complete” for every downstream report/UI surface — variant SKU suffix derivation policy and full operational wire-through polish continue in v0.04-4 where noted below.

---

## Purpose

v0.04-2 makes `Product` the permanent owner of product-level identifiers and `ProductVariant` the permanent owner of variant-level operational SKUs.

| Layer | Answers |
| ----- | ------- |
| Product identifiers | What commercial item is this? What ISBN/UPC/EAN/GTIN identifies it? How do imports, vendor files, POS scans, and external catalog lookup match? |
| Variant SKUs | Which exact ShelfStack sellable / stockable / reservable variant is this? |
| Manual lookup codes | What short code can staff type at POS for a frequently entered variant? |

These concepts must stay separate.

---

## Source documents

Read before implementation:

```text
docs/design/VERSION_0.04.md
docs/roadmap/v0.04-delivery-roadmap.md
docs/v0.04/README.md
docs/v0.04/v0.04-1-product-fusion/spec.md
docs/implementation/v0.04-1-completion.md
docs/v0.04/v0.04-2-product-identifiers/data-model.md
docs/v0.04/v0.04-2-product-identifiers/test-plan.md
AGENTS.md
```

---

## Core decisions

### 1. Product identifiers belong to products

`catalog_item_identifiers` is replaced by `product_identifiers`. Product identifiers are product-grain only — not variants, gift cards, store credits, orders, or buyback tickets.

### 2. Identifier validation uses families, not subtype tables

`product_identifiers.validation_family`:

```text
gtin | isbn | freeform | house
```

Staff-facing labels (`ISBN-13`, `UPC-A`, `EAN-13`, `ISBN-10`, `BIPAD`, `Publisher number`) are inferred from family, normalized value, and optional scope/metadata.

### 3. ISBN alternates are bidirectional

ShelfStack automatically maintains ISBN-10 and ISBN-13/EAN-13 alternate rows when conversion is possible.

| Entry | Behavior |
| ----- | -------- |
| ISBN-10 | Validate mod-11 → store `isbn` row → convert to ISBN-13 → store `gtin` row → make `gtin` primary |
| ISBN-13 `978…` | Validate GTIN → store `gtin` → convert to ISBN-10 → store non-primary `isbn` |
| ISBN-13 `979…` | Validate GTIN → store `gtin` → **no** ISBN-10 alternate |

### 4. Internal EANs use reserved 200–229 segments

ShelfStack-generated scannable codes use internal EAN-13 values in the `200–229` range with a shared sequential allocator.

| Prefix range | Purpose |
| ------------ | ------- |
| `20X` | Product-level identification |
| `21X` | Variant-level and future copy/unit-level identification |
| `22X` | Operational series (gift certificates, store credits, claim tickets, buyback tickets, etc.) — **reserved, not implemented in v0.04-2** |

**Active v0.04-2 segments:**

| Prefix | Use | Grain |
| -----: | --- | ----- |
| `201` | Product house identifiers | Product |
| `211` | Generated product variant SKUs | Product variant |

All other segments within `20X`, `21X`, and `22X` are reserved for future milestones.

This segment policy **supersedes** the older per-category table in prior design drafts (`200` custom, `201` bundles, `202` services, `210` legacy). See [data-model.md](data-model.md) and [VERSION_0.04.md](../../design/VERSION_0.04.md).

### 5. Product-level house identifiers are rare

Generate a `201` house identifier only when the product lacks a usable external product identifier (sideline, service, legacy product, locally manufactured item, etc.).

### 6. Every variant receives a system-assigned SKU

Every product variant must have a required, globally unique `product_variants.sku`.

New generated variant SKUs use internal EAN segment `211` via `ProductVariants::SkuAllocator`. They must **not** derive from product identifiers, `products.sku`, condition codes, or attribute suffixes.

Historical variant SKUs are preserved. Only **new** variants use the v0.04-2 allocator.

### 7. Short manual lookup codes are aliases, not SKUs

Optional short codes (`LATTE`, `101`, `COF`) resolve directly to variants at POS. They are not product identifiers and do not replace canonical variant SKUs.

**v0.04-2 thin slice:** table, model, service, basic admin assignment, POS resolution. Polished café/menu UI and bulk management defer to v0.04-4+.

### 8. `products.sku` after v0.04-2

`products.sku` remains only as a **transitional/cache field** for display, search, and legacy joins.

`product_identifiers` is the source of truth for product-level identifier lookup, duplicate detection, POS product scans, imports, and validation.

Rules:

- New code must not treat `products.sku` as the canonical product identifier.
- New product lookup behavior must not depend on `products.sku` except as an explicit **legacy fallback** during migration.
- New variant SKUs must not derive from `products.sku`.

### 9. Freeform uniqueness is scoped, not global

Freeform identifiers enforce uniqueness on:

```text
product_id + freeform_scope + normalized_identifier
```

Publisher numbers, BIPAD codes, vendor references, and legacy locals may legitimately repeat across products or sources. Do **not** use global freeform uniqueness.

### 10. `catalog_items` retained; `catalog_item_identifiers` dropped

`catalog_item_identifiers` is removed. `catalog_items` remains as a quarantined legacy metadata shell and does **not** own active identifiers after v0.04-2.

---

## Scope

### In scope

1. Add `product_identifiers`, `internal_ean_sequences`, `product_variant_lookup_codes`.
2. Validation families: `gtin`, `isbn`, `freeform`, `house`.
3. Replace `CatalogIdentifierService` with `ProductIdentifierService`.
4. Backfill from `catalog_item_identifiers` and transitional `products.sku`.
5. GTIN, ISBN-10 mod-11, and ISBN alternate behavior.
6. House EAN generation from segment `201`; variant SKU generation from segment `211`.
7. Remove suffix-based variant SKU generation for **new** variants.
8. Thin slice: variant lookup codes (model + service + basic CRUD + POS resolution).
9. Product-scoped identifier CRUD, validation previews, audit events.
10. **Mandatory** POS scan resolution via `Pos::LineLookup` (see wire-through table below).
11. External catalog import / duplicate detection / local ISBN match on `product_identifiers`.
12. Ingram import stops creating `catalog_item_identifiers`.
13. Drop `catalog_item_identifiers`; remove/quarantine `CatalogIdentifierService`.
14. Verification task: `rails shelfstack:v0042:verify_product_identifiers`.

### Wire-through phasing

| Must ship in v0.04-2 | Defer to v0.04-4+ |
| -------------------- | ----------------- |
| `Pos::LineLookup` variant SKU + lookup code + product identifier resolution | Report/search polish |
| ISBN-10 / ISBN-13 cross-form lookup | Full item workspace identifier UI polish |
| `Inventory::VariantLookup` identifier paths | Broad historical snapshot field renames |
| `ExternalCatalog::ProductBuilder`, `DuplicateDetector`, `LocalIsbnMatch` | Noncritical report joins |
| `ExternalCatalog::ImportCandidate` product identifier writes | Deep Ingram UI polish |
| Ingram stops creating `catalog_item_identifiers` | Bulk lookup-code management |
| Buyback basic identifier resolution | Café/menu button UI |
| Product identifier CRUD on product scope (setup modals / item setup minimum) | Open-ring workflow integration |

POS scan resolution is **core v0.04-2 scope**, not optional. Once `catalog_item_identifiers` is dropped, scan paths must work through the new model.

### Out of scope

1. Product groups (v0.04-3).
2. Demand, allocations, sourcing, PO/receiving quantity lifecycle.
3. Full removal of `catalog_items`.
4. Gift card / store credit / claim ticket / buyback ticket barcodes (`22X` segments).
5. Copy-level serialized inventory.
6. Full item setup redesign beyond identifier and lookup-code management.

---

## Migration rules

### From `catalog_item_identifiers`

Copy via `products.catalog_item_id` → linked products. Preserve primary, source, and active flags when possible. Auto-create missing ISBN alternates. Flag uniqueness conflicts for review.

### From transitional `products.sku`

When a product has no identifiers:

| Condition | Action |
| --------- | ------ |
| Valid GTIN | Create `gtin` |
| Valid `201` house EAN | Create `house` |
| Valid ISBN-10 | Create `isbn` + converted `gtin` |
| Value starts with `P` (v0.04-1 transitional SKU) | Create `freeform` with `freeform_scope: legacy_product_sku` — **do not** convert to `house` |
| Otherwise | Create `freeform` with appropriate scope; set primary if none exists |

### Legacy local identifiers (`L...`)

Legacy `L000000001` values are **not** converted in place to `house` identifiers.

1. Preserve `L...` as `freeform` with `freeform_scope: legacy_local`.
2. If the product needs a scannable product-level identifier and has no external GTIN/ISBN, generate a **new** `201` house EAN.
3. Keep both rows when applicable (legacy freeform for history; house for future scanning).

### Transitional v0.04-1 product SKUs (`P########`)

v0.04-1 `AddItem::ProductSkuGenerator` values such as `P00000001` are not permanent house EANs.

1. Preserve as `freeform` with `freeform_scope: legacy_product_sku`.
2. Do **not** convert `P...` to `house`.
3. Generate new `201` house EAN only when a scannable product identifier is needed.

Do **not** create variant SKUs from product identifiers during migration.

---

## Lookup behavior

### POS exact-match order

```text
1. product_variants.sku (exact)
2. product_variant_lookup_codes.normalized_code (exact)
3. product_identifiers.normalized_identifier (exact, active)
4. Cross-form ISBN candidates (ISBN-10 ↔ ISBN-13)
5. Product-level match + one active variant → auto-select
6. Product-level match + multiple active variants → ambiguity prompt
7. Text search
```

Rules:

- Variant SKU and lookup codes resolve at **variant** grain.
- Product identifiers resolve at **product** grain.
- Cross-form candidates apply to product-grain matches only.
- Segment `201` house codes resolve as product identifiers; segment `211` codes resolve as variant SKUs.
- `products.sku` is legacy fallback only when documented — not a primary scan path after migration.

---

## Services

| Service | Role |
| ------- | ---- |
| `ProductIdentifierService` | Replaces `CatalogIdentifierService`; CRUD, validation, ISBN alternates, house generation |
| `InternalEanAllocator` | Sequential EAN-13 generation per segment (`201`, `211` in v0.04-2) |
| `ProductVariants::SkuAllocator` | System-assigned variant SKUs via segment `211` |
| `ProductVariants::LookupCodeService` | Short manual lookup codes; normalization and POS resolution |

`SkuGenerator` becomes a thin deprecated facade or is split: **product lookup** uses `ProductIdentifierService`; **variant creation** uses `ProductVariants::SkuAllocator`.

---

## UI (minimum v0.04-2)

**Product:** add/edit/inactivate identifiers, validation preview, set primary, generate house EAN, view ISBN alternates.

**Variant:** show canonical system-assigned SKU; optional lookup code assignment (basic CRUD). Generated SKUs are not normally editable; admin override requires audit if retained.

Polished café/menu UX defers to v0.04-4.

---

## Audit events

```text
product_identifier.created
product_identifier.updated
product_identifier.inactivated
product_identifier.primary_changed
product_identifier.house_generated
product_identifier.isbn10_converted
product_identifier.isbn13_alternate_created
variant_sku.generated
variant_sku.changed
variant_lookup_code.created
variant_lookup_code.inactivated
```

---

## Definition of done

1. `product_identifiers`, `internal_ean_sequences`, and `product_variant_lookup_codes` exist.
2. `catalog_item_identifiers` is dropped; `catalog_items` is retained with no active identifier ownership.
3. `ProductIdentifierService` replaces `CatalogIdentifierService`.
4. Identifier CRUD and validation preview work on products.
5. GTIN, ISBN-10, and ISBN alternate behavior matches this spec.
6. House generation uses segment `201`; variant SKU generation uses segment `211`.
7. New variant SKUs do not derive from product identifiers, `products.sku`, conditions, or attributes.
8. Historical variant SKUs preserved.
9. Thin lookup-code slice: model, service, basic assignment, POS resolution.
10. `Pos::LineLookup` resolves variant SKU, lookup codes, and product identifiers (mandatory).
11. External import / duplicate / local ISBN match use `product_identifiers`.
12. Ingram import no longer creates `catalog_item_identifiers`.
13. `products.sku` documented as cache/legacy only; no new canonical lookup on it.
14. Freeform uniqueness is scoped per product + scope.
15. Legacy `L...` and `P...` migration rules applied.
16. `rails shelfstack:v0042:verify_product_identifiers` passes.
17. Full test suite and seed validation pass.
18. [v0.04-2 completion](../../implementation/v0.04-2-completion.md) note created when implementation lands.

Flip status to **Complete** only after CI green on the merge commit.

---

## Next milestone

**v0.04-4 — Variant-grain wire-through** (operational polish, reports, remaining transitional joins) and/or **v0.04-3 — Product groups**. v0.04-3 must not reopen identifier ownership, segment policy, or variant SKU policy.
