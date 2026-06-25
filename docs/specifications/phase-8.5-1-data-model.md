# Phase 8.5-1 Data Model — POS Discount Model & Calculation

This document describes schema additions for Phase 8.5-1.

Functional behavior: [phase-8.5-1-pos-discount-spec.md](phase-8.5-1-pos-discount-spec.md)

Roadmap: [phase-8.5-1-pos-discount-model.md](../roadmap/phase-8.5-1-pos-discount-model.md)

Constraint sections distinguish **implemented database** rules (migration `20250706120000_create_phase85_1_pos_discount_foundation.rb`) from **application/model validations** and **recommended future** database hardening.

---

# 1. New tables

## 1.1 `discount_reasons`

Seedable/admin-maintainable discount reason reference data.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| `id` | bigint | no | — |
| `reason_key` | string | no | — |
| `name` | string | no | — |
| `description` | text | yes | — |
| `requires_note` | boolean | no | `false` |
| `requires_authorization` | boolean | no | `false` |
| `active` | boolean | no | `true` |
| `sort_order` | integer | no | `0` |
| `created_at` | datetime | no | — |
| `updated_at` | datetime | no | — |

### Implemented database indexes

- unique index on `reason_key`
- unique index on `name`

### Application/model validations

- `reason_key` presence, uniqueness, lowercase snake_case normalization
- `name` presence, uniqueness
- `sort_order` numericality `>= 0`

### Recommended future database constraints

- index on `(active, sort_order)` for Setup list ordering

---

## 1.2 `pos_discount_applications`

One row per discount action (line or transaction scope).

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| `id` | bigint | no | — |
| `pos_transaction_id` | bigint | no | — |
| `pos_transaction_line_id` | bigint | yes | — |
| `discount_reason_id` | bigint | no | — |
| `pos_authorization_id` | bigint | yes | — |
| `scope` | string | no | — |
| `source` | string | no | — |
| `discount_method` | string | no | — |
| `entered_amount_cents` | integer | yes | — |
| `entered_percent_bps` | integer | yes | — |
| `target_price_cents` | integer | yes | — |
| `base_amount_cents` | integer | no | `0` |
| `calculated_discount_cents` | integer | no | `0` |
| `applied_discount_cents` | integer | no | `0` |
| `stack_order` | integer | no | — |
| `note` | text | yes | — |
| `applied_by_user_id` | bigint | no | — |
| `approved_by_user_id` | bigint | yes | — |
| `applied_at` | datetime | no | — |
| `voided_at` | datetime | yes | — |
| `voided_by_user_id` | bigint | yes | — |
| `void_reason` | text | yes | — |
| `details` | jsonb | no | `{}` |
| `created_at` | datetime | no | — |
| `updated_at` | datetime | no | — |

### Implemented database check constraints

- `scope IN ('line', 'transaction')`
- `source IN ('manual', 'system', 'promotion', 'legacy')`
- `discount_method IN ('amount', 'percent', 'price_override')`
- `base_amount_cents >= 0`
- `calculated_discount_cents >= 0`
- `applied_discount_cents >= 0`
- `entered_percent_bps IS NULL OR (entered_percent_bps >= 0 AND entered_percent_bps <= 10000)`

### Implemented database indexes

- index on `pos_transaction_id` (FK)
- index on `pos_transaction_line_id` (FK)
- index on `discount_reason_id` (FK)
- index on `pos_authorization_id` (FK)
- composite index on `(pos_transaction_id, voided_at, stack_order)`

### Application/model validations

- line scope: `pos_transaction_line_id` required; line must belong to same transaction
- transaction scope: `pos_transaction_line_id` must be blank
- method-specific entered fields (`entered_amount_cents`, `entered_percent_bps`, `target_price_cents`)
- non-negative totals; `stack_order >= 1`
- no updates when parent transaction is locked

### Recommended future database constraints

- partial index on `(pos_transaction_id)` where `voided_at IS NULL`
- check constraints enforcing line vs transaction scope rules on `pos_transaction_line_id`

---

## 1.3 `pos_discount_allocations`

Line-level impact of each discount application; denormalized for reporting.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| `id` | bigint | no | — |
| `pos_discount_application_id` | bigint | no | — |
| `pos_transaction_id` | bigint | no | — |
| `pos_transaction_line_id` | bigint | no | — |
| `scope` | string | no | — |
| `allocation_base_cents` | integer | no | `0` |
| `allocated_discount_cents` | integer | no | `0` |
| `line_number_snapshot` | integer | yes | — |
| `product_variant_id` | bigint | yes | — |
| `product_id` | bigint | yes | — |
| `sub_department_id` | bigint | yes | — |
| `department_id` | bigint | yes | — |
| `tax_category_id` | bigint | yes | — |
| `variant_sku_snapshot` | string | yes | — |
| `variant_name_snapshot` | string | yes | — |
| `product_name_snapshot` | string | yes | — |
| `sub_department_name_snapshot` | string | yes | — |
| `department_name_snapshot` | string | yes | — |
| `created_at` | datetime | no | — |
| `updated_at` | datetime | no | — |

### Implemented database check constraints

- `scope IN ('line', 'transaction')`
- `allocation_base_cents >= 0`
- `allocated_discount_cents >= 0`

### Implemented database indexes

- indexes on FK columns created by `t.references` (`pos_discount_application_id`, `pos_transaction_id`, `pos_transaction_line_id`, catalog snapshot FKs)

### Application/model validations

- allocation line must belong to same transaction as application
- non-negative cents

### Recommended future database constraints

- composite index on `(pos_transaction_id, pos_transaction_line_id)` for line-level discount reports

---

# 2. Schema changes on existing tables

## 2.1–2.4 Catalog `discountable` flags

`departments`, `sub_departments`, `products`, and `product_variants` each add:

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| `discountable` | boolean | no | `true` |

---

# 3. Unchanged cached totals

Phase 8.5-1 does **not** remove or rename existing aggregate discount columns:

| Table | Column | Role after 8.5-1 |
|-------|--------|------------------|
| `pos_transactions` | `discount_cents` | Cached total of active transaction-scope allocations |
| `pos_transaction_lines` | `line_discount_cents` | Cached total of active line-scope allocations |
| `pos_transaction_lines` | `transaction_discount_cents` | Cached total of active transaction-scope allocations per line |

---

# 4. Reporting snapshots

Allocation reports must read denormalized columns on `pos_discount_allocations` (IDs and `*_snapshot` text fields), not live catalog or classification joins. Snapshot columns are written when `Pos::DiscountRecalculator` creates allocations.
