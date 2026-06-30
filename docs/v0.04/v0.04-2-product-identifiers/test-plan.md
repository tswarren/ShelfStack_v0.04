# v0.04-2 Product Identifiers — Test Plan

## Status

**Planned**

**Functional spec:** [spec.md](spec.md) · **Data model:** [data-model.md](data-model.md)

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Service unit | `ProductIdentifierService`, `InternalEanAllocator`, `ProductVariants::SkuAllocator`, `ProductVariants::LookupCodeService` |
| Migration / backfill | Identifier copy, `L...` / `P...` rules, conflict reporting |
| POS lookup | `Pos::LineLookup` order and ambiguity (mandatory v0.04-2) |
| Import | ProductBuilder, DuplicateDetector, LocalIsbnMatch, Ingram |
| Authorization / audit | Identifier CRUD permissions, audit events |
| Integration | Add Item, buyback resolve, inventory variant lookup |
| Verification rake | `rails shelfstack:v0042:verify_product_identifiers` |

---

## ProductIdentifierService

1. Valid GTIN accepted; invalid check digit rejected.
2. Valid ISBN-10 accepted; invalid mod-11 rejected.
3. ISBN-10 entry creates converted ISBN-13 `gtin` primary.
4. ISBN-13 `978…` creates non-primary ISBN-10 alternate.
5. ISBN-13 `979…` does not create ISBN-10 alternate.
6. Existing alternates reused, not duplicated.
7. One active primary per product enforced.
8. Duplicate active GTIN rejected globally.
9. Duplicate active ISBN-10 rejected globally.
10. Freeform scoped uniqueness: same value allowed on different products/scopes.
11. House generation uses segment `201` with valid EAN-13 check digit.
12. House rejects unsupported segment outside active policy.
13. Legacy `L...` preserved as freeform `legacy_local`, not converted to house.
14. Transitional `P...` preserved as freeform `legacy_product_sku`.

---

## InternalEanAllocator

1. Generates valid 13-digit EAN.
2. Separate counter per segment.
3. EAN-13 check digit correct (not UPC weighting).
4. Rejects segment outside `200–229`.
5. Rejects inactive segment/purpose pairs.
6. Allows `201` / `product_house` and `211` / `variant_sku`.
7. Does not generate `22X` in v0.04-2.
8. Concurrency-safe under row lock.

---

## ProductVariants::SkuAllocator

1. New variant receives generated SKU from segment `211`.
2. SKU is globally unique and EAN-13 valid.
3. Does not include product identifier, `products.sku`, condition, or attribute suffix.
4. Existing historical SKU not overwritten on save.
5. Buyback-created used variants receive new allocator SKU.

---

## ProductVariants::LookupCodeService

1. Adds and normalizes manual code.
2. Enforces store-scoped and global uniqueness.
3. Rejects invalid characters / length.
4. Warns or rejects GTIN-length numeric codes.
5. POS resolves lookup code to exact variant.

---

## Pos::LineLookup (mandatory)

1. Variant SKU scan → exact variant.
2. Lookup code → exact variant (before product identifier).
3. ISBN-13 scan → product; auto-select when one active variant.
4. ISBN-10 → same product via alternate/candidate.
5. `201…` house → product grain.
6. `211…` variant SKU → variant grain.
7. Multiple active variants → ambiguity prompt.
8. `products.sku` not primary path when `product_identifiers` exist (legacy fallback only if documented).
9. Text search still works.

---

## Import and duplicate detection

1. ProductBuilder creates `product_identifiers`.
2. DuplicateDetector matches via `product_identifiers` + transitional paths.
3. LocalIsbnMatch uses product grain.
4. Ingram import does not create `catalog_item_identifiers`.
5. Imported ISBN alternates follow 978/979 rules.

---

## Migration verification

Task: `rails shelfstack:v0042:verify_product_identifiers`

Report at minimum:

```text
products total
products with identifiers
products with active primary
products without identifiers
counts by validation_family
GTIN/ISBN duplicate conflicts
legacy_local / legacy_product_sku counts
201 / 211 sequence counters
zero app references to catalog_item_identifiers
```

---

## Definition of done (testing)

- All sections above covered by automated tests where practical.
- Full suite green; `shelfstack:seeds:validate` passes.
- No test fixtures depend on `catalog_item_identifiers` after cutover.
- CI green on merge commit.

---

## Deferred to v0.04-4 test scope

- Report snapshot field renames.
- Polished café/menu lookup-code UI flows.
- Full Items workspace identifier UX polish beyond minimum CRUD.
