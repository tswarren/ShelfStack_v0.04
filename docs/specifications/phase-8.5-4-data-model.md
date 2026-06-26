# Phase 8.5-4 Data Model — Item Data Quality

Functional behavior: [phase-8.5-4-item-data-quality-spec.md](phase-8.5-4-item-data-quality-spec.md)

Roadmap: [phase-8.5-4-item-data-quality.md](../roadmap/phase-8.5-4-item-data-quality.md)

---

## 1. Catalog thumbnail (Active Storage)

No relational column migration. Attach to `CatalogItem`:

```ruby
has_one_attached :primary_thumbnail
```

Validation aligns with `Product#cover_image`:

- Allowed types: JPEG, PNG, WebP, GIF
- Max size: 5 MB

## 2. Display resolution order

1. Product `cover_image` (override)
2. Catalog item `primary_thumbnail`
3. Placeholder by catalog item type / format

Variant-level image overrides are deferred.

## 3. Unchanged (8.5-3)

- `products.preferred_vendor_id`
- `product_variants.preferred_vendor_id`
- `product_variants.orderable`

8.5-4 consumes these fields; no new ordering columns.
