# Associate existing categories with merchandise classes

## Summary

Link existing `Category` records to `MerchandiseClass` so current category behavior can transition gradually.

This is the least disruptive migration path. Existing categories can continue to work, while pricing/tax/default behavior begins moving toward merchandise classes.

## Proposed relationship

Initial approach:

```text
Category belongs_to MerchandiseClass
```

Later, `ProductVariant` may support a direct merchandise class override if needed.

## Why this approach

This avoids requiring every product variant to be immediately migrated. It lets existing categories inherit behavior from a merchandise class while preserving the existing category selector in item and variant forms.

## Acceptance criteria

* `categories` table has `merchandise_class_id`.
* `Category` belongs to `MerchandiseClass`.
* Existing categories are backfilled to reasonable merchandise classes.
* Category setup UI allows selecting a merchandise class.
* Product/variant forms continue to work.
* No existing category-based reports break.

