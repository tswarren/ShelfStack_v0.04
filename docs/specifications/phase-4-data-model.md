# Phase 4 Data Model

## Purpose

This document defines the Phase 4 ShelfStack data model, including tables, fields, recommended indexes, constraints, controlled values, and seed data.

This document should be treated as the source of truth for Phase 4 migrations.

Functional behavior: [phase-4-inventory-foundation-spec.md](phase-4-inventory-foundation-spec.md)

---

# 1. Naming Conventions

## 1.1 Tables

Phase 4 introduces:

```text
inventory_reason_codes
inventory_locations
inventory_adjustments
inventory_adjustment_lines
inventory_postings
inventory_ledger_entries
inventory_balances
```

Phase 4 also **restores** a column on an existing table:

```text
sub_departments.default_margin_target_bps
```

## 1.2 Money

Store currency amounts as integer cents:

```text
unit_cost_cents
total_cost_cents
unit_retail_cents
total_retail_cents
inventory_cost_value_cents
inventory_retail_value_cents
```

## 1.3 Basis points

`default_margin_target_bps` uses integer basis points (0–10000).

## 1.4 Booleans

Use `active` without `is_` prefix.

---

# 2. Schema Change on Existing Table

## 2.1 `sub_departments.default_margin_target_bps`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `default_margin_target_bps` | integer | nullable | Restored for Phase 4 cost estimation. |

Check constraint:

```sql
default_margin_target_bps IS NULL
OR (default_margin_target_bps >= 0 AND default_margin_target_bps <= 10000)
```

CSV seed column `default_margin_target_bps` is optional on `sub_departments.csv`.

---

# 3. Table Matrix

## 3.1 `inventory_reason_codes`

Global setup for adjustment reasons.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `reason_key` | string | null false, unique | Stable seed key. |
| `name` | string | null false, unique | Display name. |
| `sort_order` | integer | null false, default 0 | |
| `active` | boolean | null false, default true | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Indexes

* unique on `reason_key`
* unique on `name`
* index on `active`

---

## 3.2 `inventory_locations`

Store-scoped optional location context.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `store_id` | bigint | null false, FK → stores | |
| `name` | string | null false | |
| `short_name` | string | null false, limit 40 | |
| `sort_order` | integer | null false, default 0 | |
| `active` | boolean | null false, default true | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Uniqueness

* unique `(store_id, short_name)`

### Indexes

* index on `store_id`
* index on `active`

---

## 3.3 `inventory_adjustments`

Draft/posted adjustment header.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `store_id` | bigint | null false, FK → stores | |
| `adjustment_type` | string | null false | Controlled value. |
| `status` | string | null false, default `draft` | Controlled value. |
| `notes` | text | nullable | |
| `posted_at` | datetime | nullable | Set on post. |
| `posted_by_user_id` | bigint | nullable, FK → users | |
| `inventory_posting_id` | bigint | nullable, FK → inventory_postings | Set on post. |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Controlled values

**`adjustment_type`**

```text
opening_inventory
manual_adjustment
```

**`status`**

```text
draft
posted
cancelled
```

### Indexes

* index on `(store_id, status)`
* index on `adjustment_type`
* index on `inventory_posting_id`

---

## 3.4 `inventory_adjustment_lines`

Draft lines; copied to ledger on post.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `inventory_adjustment_id` | bigint | null false, FK | |
| `line_number` | integer | null false | 1-based per adjustment. |
| `product_variant_id` | bigint | null false, FK | |
| `quantity_delta` | integer | null false | Signed; non-zero at post. |
| `unit_cost_cents` | integer | nullable | Manual override. |
| `inventory_location_id` | bigint | nullable, FK | Optional context. |
| `inventory_reason_code_id` | bigint | nullable, FK | Optional. |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Uniqueness

* unique `(inventory_adjustment_id, line_number)`

### Check constraints

```text
quantity_delta <> 0   -- enforced at post time; draft may allow 0 until validation
unit_cost_cents IS NULL OR unit_cost_cents >= 0
```

### Indexes

* index on `product_variant_id`
* index on `inventory_adjustment_id`

---

## 3.5 `inventory_postings`

Posted inventory event (immutable).

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `posting_type` | string | null false | Controlled value. |
| `source_type` | string | null false | Polymorphic type. |
| `source_id` | bigint | null false | Polymorphic id. |
| `store_id` | bigint | null false, FK → stores | |
| `posted_at` | datetime | null false | |
| `posted_by_user_id` | bigint | null false, FK → users | |
| `workstation_id` | bigint | nullable, FK → workstations | |
| `idempotency_key` | string | null false, unique | Stable per source post. |
| `reversal_of_posting_id` | bigint | nullable, FK → inventory_postings | |
| `reversed_by_posting_id` | bigint | nullable, FK → inventory_postings | |
| `notes` | text | nullable | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Controlled values — `posting_type`

Phase 4:

```text
opening_inventory
manual_adjustment
balance_correction
```

Reserved for later phases:

```text
receiving
pos_sale
customer_return
vendor_return
used_buyback
transfer
```

### Uniqueness

* unique `(source_type, source_id)`
* unique `idempotency_key`

### Indexes

* index on `(store_id, posted_at)`
* index on `posting_type`

---

## 3.6 `inventory_ledger_entries`

Append-only quantity/value effects.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `inventory_posting_id` | bigint | null false, FK | |
| `line_number` | integer | null false | Per posting. |
| `product_variant_id` | bigint | null false, FK | |
| `store_id` | bigint | null false, FK → stores | Denormalized from posting for query speed. |
| `inventory_location_id` | bigint | nullable, FK | Optional context. |
| `movement_type` | string | null false | Controlled value. |
| `quantity_delta` | integer | null false | Signed. |
| `unit_cost_cents` | integer | nullable | Snapshot. |
| `total_cost_cents` | integer | nullable | Snapshot. |
| `unit_retail_cents` | integer | nullable | Snapshot. |
| `total_retail_cents` | integer | nullable | Snapshot. |
| `cost_source` | string | null false | Controlled value. |
| `retail_source` | string | null false | Controlled value. |
| `inventory_reason_code_id` | bigint | nullable, FK | |
| `occurred_at` | datetime | null false | Usually posting `posted_at`. |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Controlled values — `movement_type`

Phase 4:

```text
opening_balance
manual_adjustment
correction
recount_adjustment
```

Reserved:

```text
received
sold
customer_return
used_buyback
vendor_return
transfer_in
transfer_out
```

### Controlled values — `cost_source`

```text
manual
margin_estimate
unknown
```

### Controlled values — `retail_source`

```text
variant_selling_price
unknown
```

### Uniqueness

* unique `(inventory_posting_id, line_number)`

### Indexes

* index on `(store_id, product_variant_id)`
* index on `(product_variant_id, occurred_at)`
* index on `inventory_posting_id`

---

## 3.7 `inventory_balances`

Cached balance per store + variant.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `store_id` | bigint | null false, FK | |
| `product_variant_id` | bigint | null false, FK | |
| `quantity_on_hand` | integer | null false, default 0 | Signed allowed. |
| `quantity_available` | integer | null false, default 0 | Phase 4 equals on hand. |
| `inventory_cost_value_cents` | integer | null false, default 0 | |
| `inventory_retail_value_cents` | integer | null false, default 0 | |
| `estimated_unit_cost_cents` | integer | nullable | Latest snapshot. |
| `unit_retail_cents` | integer | nullable | Latest snapshot. |
| `cost_source` | string | nullable | Latest snapshot. |
| `retail_source` | string | nullable | Latest snapshot. |
| `last_posting_id` | bigint | nullable, FK | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Uniqueness

* unique `(store_id, product_variant_id)`

### Invariant

```text
quantity_on_hand = SUM(inventory_ledger_entries.quantity_delta)
  FOR matching store_id + product_variant_id
```

### Indexes

* unique index on `(store_id, product_variant_id)`
* index on `(store_id, quantity_on_hand)` for negative exception queries

---

# 4. Foreign Keys

```text
inventory_locations.store_id → stores.id
inventory_adjustments.store_id → stores.id
inventory_adjustments.posted_by_user_id → users.id
inventory_adjustments.inventory_posting_id → inventory_postings.id
inventory_adjustment_lines.inventory_adjustment_id → inventory_adjustments.id
inventory_adjustment_lines.product_variant_id → product_variants.id
inventory_adjustment_lines.inventory_location_id → inventory_locations.id
inventory_adjustment_lines.inventory_reason_code_id → inventory_reason_codes.id
inventory_postings.store_id → stores.id
inventory_postings.posted_by_user_id → users.id
inventory_postings.workstation_id → workstations.id
inventory_ledger_entries.inventory_posting_id → inventory_postings.id
inventory_ledger_entries.product_variant_id → product_variants.id
inventory_ledger_entries.store_id → stores.id
inventory_ledger_entries.inventory_location_id → inventory_locations.id
inventory_ledger_entries.inventory_reason_code_id → inventory_reason_codes.id
inventory_balances.store_id → stores.id
inventory_balances.product_variant_id → product_variants.id
inventory_balances.last_posting_id → inventory_postings.id
```

Use `restrict_with_error` or equivalent on variants/stores referenced by balances and ledger history.

---

# 5. Seed Data

## 5.1 Inventory reason codes

Idempotent seed keys (examples):

| `reason_key` | `name` |
| --- | --- |
| `opening_balance` | Opening Balance |
| `cycle_count` | Cycle Count |
| `damage` | Damage |
| `shrink` | Shrink / Loss |
| `data_correction` | Data Correction |
| `recount` | Recount Adjustment |

## 5.2 Inventory locations

Optional per-store seeds (development):

```text
sales_floor
back_room
receiving
damaged_review
```

## 5.3 Permissions

See `db/seeds/phase4_permissions.rb` (implementation).

## 5.4 Subdepartment margins

Extend `sub_departments.csv` with optional `default_margin_target_bps`.

Suggested defaults when blank (implementation seed helper):

| `default_pricing_model` | Suggested margin bps |
| --- | ---: |
| `trade_discount` | 4000 |
| `net_cost_markup` | 5000 |
| `blended_lot_cost` | 4500 |
| `recipe_cost` | 6000 |

---

# 6. Deferred Tables

Not in Phase 4:

```text
inventory_location_balances
inventory_location_movements
inventory_transfers
inventory_transfer_lines
inventory_reservations
```

---

# 7. Migration Checklist

1. Restore `sub_departments.default_margin_target_bps` with check constraint.
2. Create Phase 4 tables in dependency order: reason codes → locations → postings → adjustments → lines → ledger entries → balances (adjust posting FK on adjustments after postings exist).
3. Add all foreign keys and unique indexes.
4. Add model validations for controlled values.
5. Seed reason codes and permissions idempotently.
6. Document audit events in spec.
7. Implement services before UI.
8. Add tests per phase-4-test-plan.md.
