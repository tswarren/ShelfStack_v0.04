# Classification Simplification Cleanup

## Purpose

Record of the `cleanup/classification-simplification` branch (migration `20250616120000_classification_simplification_cleanup`).

This cleanup removes unused Phase 2 and Phase 3B classification artifacts and aligns the live schema with [classification-target-spec.md](../specifications/classification-target-spec.md).

---

## Removed tables

| Table | Reason |
| :---- | :----- |
| `categories` | Phase 2 legacy; sellable items use `product_variants.sub_department_id` |
| `accounting_mappings` | Never wired into runtime; GL posts via `department.gl_account_code` |

---

## Removed `sub_departments` columns

These fields were seeded and shown in setup but not read by item/POS flows:

- `default_margin_target_bps`
- `default_supplier_discount_bps`
- `has_list_price`
- `vendor_discounts_from_list_price`
- `store_marks_up_from_cost`
- `used_sales_allowed`
- `default_sales_account_code`
- `default_variation_type`
- `default_inventory_behavior`

**Retained operational fields:** identity, `department_id`, `default_tax_category_id`, `default_pricing_model`, `vendor_returnable_default`, `buyback_allowed`, `active`.

---

## BISAC flattening

- BISAC import writes flat `category_nodes` (`parent_id` always `NULL`).
- Removed `category_nodes.default_store_category_id` and BISAC→store-category suggestion in `CatalogItemStoreCategorySync`.
- Dropped partial unique index on root node names to allow duplicate headings under flat BISAC; `node_key` remains unique per scheme.
- One-time rake for existing DBs: `bin/rails shelfstack:bisac:flatten` (also runs in migration `up`).

---

## Removed setup surfaces

- Categories CRUD (`setup/categories`)
- Accounting mappings CRUD (`setup/accounting_mappings`)
- Related permissions and seeds

---

## Existing database note

Running the migration drops `categories` and `accounting_mappings` data. For dev/demo environments, `db:reset` or migrate plus re-seed is sufficient.
