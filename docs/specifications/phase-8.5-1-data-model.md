# Phase 8.5-1 Data Model — POS Discount Model & Calculation

This document describes schema additions for Phase 8.5-1.

Functional behavior: [phase-8.5-1-pos-discount-spec.md](phase-8.5-1-pos-discount-spec.md)

Roadmap: [phase-8.5-1-pos-discount-mdel](../roadmap/phase-8.5-1-pos-discount-mdel)

---

# 1. New tables

## 1.1 `discount_reasons`

Seedable/admin-maintainable discount reason reference data.

| Column | Type | Nullable | Default | Check |
|--------|------|----------|---------|-------|
| `id` | bigint | no | — | PK |
| `reason_key` | string | no | — | unique, lowercase snake_case |
| `name` | string | no | — | — |
| `description` | text | yes | — | — |
| `requires_note` | boolean | no | `false` | — |
| `requires_authorization` | boolean | no | `false` | — |
| `active` | boolean | no | `true` | — |
| `sort_order` | integer | no | `0` | `>= 0` |
| `created_at` | datetime | no | — | — |
| `updated_at` | datetime | no | — | — |

### Indexes and constraints

- unique index on `reason_key`
- index on `(active, sort_order)`

---

## 1.2 `pos_discount_applications`

One row per discount action (line or transaction scope).

| Column | Type | Nullable | Default | Check |
|--------|------|----------|---------|-------|
| `id` | bigint | no | — | PK |
| `pos_transaction_id` | bigint | no | — | FK → `pos_transactions` |
| `pos_transaction_line_id` | bigint | yes | — | FK → `pos_transaction_lines`; required when `scope = line` |
| `discount_reason_id` | bigint | no | — | FK → `discount_reasons` |
| `pos_authorization_id` | bigint | yes | — | FK → `pos_authorizations` |
| `scope` | string | no | — | `line` or `transaction` |
| `source` | string | no | — | `manual`, `system`, `promotion`, or `legacy` |
| `discount_method` | string | no | — | `amount`, `percent`, or `price_override` |
| `entered_amount_cents` | integer | yes | — | `>= 0` when present |
| `entered_percent_bps` | integer | yes | — | `0..10000` when present |
| `target_price_cents` | integer | yes | — | `>= 0` when present |
| `base_amount_cents` | integer | no | `0` | `>= 0` |
| `calculated_discount_cents` | integer | no | `0` | `>= 0` |
| `applied_discount_cents` | integer | no | `0` | `>= 0` |
| `stack_order` | integer | no | — | `>= 1` |
| `note` | text | yes | — | — |
| `applied_by_user_id` | bigint | no | — | FK → `users` |
| `approved_by_user_id` | bigint | yes | — | FK → `users` |
| `applied_at` | datetime | no | — | — |
| `voided_at` | datetime | yes | — | — |
| `voided_by_user_id` | bigint | yes | — | FK → `users` |
| `void_reason` | text | yes | — | — |
| `details` | jsonb | no | `{}` | — |
| `created_at` | datetime | no | — | — |
| `updated_at` | datetime | no | — | — |

### Check constraints

- `scope IN ('line', 'transaction')`
- `source IN ('manual', 'system', 'promotion', 'legacy')`
- `discount_method IN ('amount', 'percent', 'price_override')`
- line-scope: `pos_transaction_line_id IS NOT NULL`
- transaction-scope: `pos_transaction_line_id IS NULL` (application-level; allocations still per line)

### Indexes and constraints

- index on `pos_transaction_id`
- index on `pos_transaction_line_id`
- index on `discount_reason_id`
- index on `pos_authorization_id`
- index on `(pos_transaction_id, stack_order)`
- partial index on `(pos_transaction_id)` where `voided_at IS NULL` (active applications)

---

## 1.3 `pos_discount_allocations`

Line-level impact of each discount application; denormalized for reporting.

| Column | Type | Nullable | Default | Check |
|--------|------|----------|---------|-------|
| `id` | bigint | no | — | PK |
| `pos_discount_application_id` | bigint | no | — | FK → `pos_discount_applications` |
| `pos_transaction_id` | bigint | no | — | FK → `pos_transactions` |
| `pos_transaction_line_id` | bigint | no | — | FK → `pos_transaction_lines` |
| `scope` | string | no | — | `line` or `transaction` |
| `allocation_base_cents` | integer | no | `0` | `>= 0` |
| `allocated_discount_cents` | integer | no | `0` | `>= 0` |
| `line_number_snapshot` | integer | yes | — | — |
| `product_variant_id` | bigint | yes | — | FK → `product_variants` (snapshot reference) |
| `product_id` | bigint | yes | — | FK → `products` (snapshot reference) |
| `sub_department_id` | bigint | yes | — | FK → `sub_departments` (snapshot reference) |
| `department_id` | bigint | yes | — | FK → `departments` (snapshot reference) |
| `tax_category_id` | bigint | yes | — | FK → `tax_categories` (snapshot reference) |
| `variant_sku_snapshot` | string | yes | — | — |
| `variant_name_snapshot` | string | yes | — | — |
| `product_name_snapshot` | string | yes | — | — |
| `sub_department_name_snapshot` | string | yes | — | — |
| `department_name_snapshot` | string | yes | — | — |
| `created_at` | datetime | no | — | — |
| `updated_at` | datetime | no | — | — |

### Check constraints

- `scope IN ('line', 'transaction')`
- `allocation_base_cents >= 0`
- `allocated_discount_cents >= 0`

### Indexes and constraints

- index on `pos_discount_application_id`
- index on `pos_transaction_id`
- index on `pos_transaction_line_id`
- index on `(pos_transaction_id, pos_transaction_line_id)`
- index on `department_id`
- index on `sub_department_id`
- index on `product_variant_id`

---

# 2. Schema changes on existing tables

## 2.1 `departments.discountable`

| Column | Type | Nullable | Default | Check |
|--------|------|----------|---------|-------|
| `discountable` | boolean | no | `true` | — |

## 2.2 `sub_departments.discountable`

| Column | Type | Nullable | Default | Check |
|--------|------|----------|---------|-------|
| `discountable` | boolean | no | `true` | — |

## 2.3 `products.discountable`

| Column | Type | Nullable | Default | Check |
|--------|------|----------|---------|-------|
| `discountable` | boolean | no | `true` | — |

## 2.4 `product_variants.discountable`

| Column | Type | Nullable | Default | Check |
|--------|------|----------|---------|-------|
| `discountable` | boolean | no | `true` | — |

---

# 3. Unchanged cached totals

Phase 8.5-1 does **not** remove or rename existing aggregate discount columns:

| Table | Column | Role after 8.5-1 |
|-------|--------|------------------|
| `pos_transactions` | `discount_cents` | Cached total of active transaction-scope applications |
| `pos_transaction_lines` | `line_discount_cents` | Cached total of active line-scope allocations |
| `pos_transaction_lines` | `transaction_discount_cents` | Cached total of active transaction-scope allocations |

---

# 4. Reporting snapshots

Allocation reports must read denormalized columns on `pos_discount_allocations` (IDs and `*_snapshot` text fields), not live catalog or classification joins. Snapshot columns are written when `Pos::DiscountRecalculator` creates allocations.
