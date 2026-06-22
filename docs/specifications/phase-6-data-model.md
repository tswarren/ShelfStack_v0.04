# Phase 6 Data Model

## Purpose

Source of truth for Phase 6 migrations.

Functional behavior: [phase-6-pos-foundation-spec.md](phase-6-pos-foundation-spec.md)

---

# 1. Naming Conventions

## 1.1 Tables

Phase 6 introduces:

```text
pos_register_sessions
pos_cash_movements
pos_transactions
pos_transaction_lines
pos_tenders
pos_receipts
pos_authorizations
pos_voids
```

## 1.2 Money and basis points

Currency: integer cents. Tax rates: integer basis points (0–10000).

## 1.3 Booleans

Use `active`-style names without `is_` prefix where applicable.

## 1.4 Inventory linkage

Do **not** add `inventory_posting_id` to `pos_transactions`.

Discover postings via:

```text
inventory_postings.source_type = PosTransaction | PosVoid
inventory_postings.source_id
```

Extend `inventory_postings.posting_type` allowed values with:

```text
pos_transaction
pos_void
```

Phase 6 does **not** use `pos_sale` or `customer_return` for new POS postings.

---

# 2. Schema Changes on Existing Tables

## 2.1 `inventory_postings.posting_type`

Add controlled values:

```text
pos_transaction
pos_void
```

## 2.2 `inventory_ledger_entries.movement_type`

Existing values `sold` and `customer_return` are used by Phase 6 POS lines. No schema change required.

---

# 3. Table Definitions

## 3.1 `pos_register_sessions`

Register / drawer session for one workstation.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `store_id` | bigint | null false, FK → stores | |
| `workstation_id` | bigint | null false, FK → workstations | |
| `opened_by_user_id` | bigint | null false, FK → users | |
| `closed_by_user_id` | bigint | nullable, FK → users | |
| `status` | string | null false | `open`, `closed`, `force_closed` |
| `business_date` | date | null false | Register business date |
| `opening_cash_cents` | integer | null false, default 0 | |
| `expected_closing_cash_cents` | integer | nullable | Set at reconcile |
| `counted_closing_cash_cents` | integer | nullable | Actual count |
| `opened_at` | datetime | null false | |
| `closed_at` | datetime | nullable | |
| `force_closed` | boolean | null false, default false | |
| `notes` | text | nullable | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Indexes and constraints

- partial unique index: one `open` session per `workstation_id`
- index on `(store_id, business_date)`
- index on `(workstation_id, opened_at)`

---

## 3.2 `pos_cash_movements`

Paid-in and paid-out during a register session.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `pos_register_session_id` | bigint | null false, FK | |
| `store_id` | bigint | null false, FK → stores | Denormalized |
| `movement_type` | string | null false | `paid_in`, `paid_out` |
| `amount_cents` | integer | null false | Positive amount |
| `reason_code` | string | nullable | Controlled or free text companion |
| `notes` | text | nullable | |
| `recorded_by_user_id` | bigint | null false, FK → users | |
| `recorded_at` | datetime | null false | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Indexes

- index on `pos_register_session_id`

---

## 3.3 `pos_transactions`

POS transaction header.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | Internal id until complete |
| `store_id` | bigint | null false, FK → stores | |
| `workstation_id` | bigint | null false, FK → workstations | Numbering scope |
| `user_session_id` | bigint | nullable, FK → user_sessions | Phase 1 session at complete |
| `pos_register_session_id` | bigint | nullable, FK | **Current open session at completion** |
| `cashier_user_id` | bigint | null false, FK → users | |
| `status` | string | null false | See spec |
| `transaction_type` | string | nullable until complete | `sale`, `return`, `exchange` |
| `transaction_number` | string | nullable until complete | Unique when present |
| `business_date` | date | nullable until complete | From register session at complete |
| `subtotal_cents` | integer | null false, default 0 | Snapshotted at complete |
| `discount_cents` | integer | null false, default 0 | Transaction-level |
| `tax_cents` | integer | null false, default 0 | |
| `rounding_cents` | integer | null false, default 0 | Cash rounding |
| `total_cents` | integer | null false, default 0 | |
| `notes` | text | nullable | |
| `suspended_at` | datetime | nullable | |
| `completed_at` | datetime | nullable | |
| `voided_at` | datetime | nullable | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Indexes and constraints

- unique index on `transaction_number` where not null
- unique index on `(workstation_id, transaction_number)` where not null
- index on `(store_id, business_date, status)`
- index on `(store_id, completed_at)`

**No** `inventory_posting_id` column.

---

## 3.4 `pos_transaction_lines`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `pos_transaction_id` | bigint | null false, FK | |
| `line_number` | integer | null false | Unique per transaction |
| `line_type` | string | null false | `variant`, `open_ring` |
| `product_variant_id` | bigint | nullable, FK | Required for `variant` |
| `product_id` | bigint | nullable, FK | Denormalized |
| `quantity` | integer | null false | Signed; negative = return |
| `unit_price_cents` | integer | null false | After override, before discount |
| `line_discount_cents` | integer | null false, default 0 | |
| `extended_price_cents` | integer | null false | Taxable base after discounts |
| `tax_cents` | integer | null false, default 0 | Line tax after round |
| `product_sku_snapshot` | string | nullable | Set at complete |
| `variant_sku_snapshot` | string | nullable | |
| `product_name_snapshot` | string | nullable | |
| `variant_name_snapshot` | string | nullable | |
| `open_ring_description` | string | nullable | Open-ring only |
| `sub_department_id` | bigint | nullable, FK | |
| `tax_category_id` | bigint | nullable, FK | |
| `tax_rate_bps` | integer | nullable | Snapshot |
| `inventory_behavior_snapshot` | string | nullable | |
| `return_disposition` | string | nullable | Return lines |
| `source_transaction_id` | bigint | nullable, FK → pos_transactions | |
| `source_transaction_line_id` | bigint | nullable, FK → pos_transaction_lines | Return linkage |
| `source_sold_quantity_snapshot` | integer | nullable | Optional audit |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Indexes

- unique `(pos_transaction_id, line_number)`
- index on `source_transaction_line_id`
- index on `product_variant_id`

---

## 3.5 `pos_tenders`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `pos_transaction_id` | bigint | null false, FK | |
| `tender_type` | string | null false | See spec |
| `amount_cents` | integer | null false | Signed for refunds |
| `reference_number` | string | nullable | Check or card stub |
| `reverses_tender_id` | bigint | nullable, FK → pos_tenders | Void reversal rows |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Indexes

- index on `pos_transaction_id`
- index on `reverses_tender_id`

---

## 3.6 `pos_receipts`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `pos_transaction_id` | bigint | null false, FK | |
| `store_id` | bigint | null false, FK → stores | |
| `receipt_number` | string | null false | Phase 6: equals `transaction_number` |
| `issued_at` | datetime | null false | Usually `completed_at` |
| `reprint_count` | integer | null false, default 0 | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Indexes

- unique on `receipt_number`
- unique on `pos_transaction_id` (one primary receipt per txn in Phase 6)

---

## 3.7 `pos_authorizations`

Supervisor override records.

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `store_id` | bigint | null false, FK → stores | |
| `pos_transaction_id` | bigint | nullable, FK | |
| `pos_register_session_id` | bigint | nullable, FK | Force-close etc. |
| `authorization_type` | string | null false | Controlled |
| `requested_by_user_id` | bigint | null false, FK → users | |
| `granted_by_user_id` | bigint | nullable, FK → users | |
| `granted_at` | datetime | nullable | |
| `denied_at` | datetime | nullable | |
| `details` | jsonb | null false, default {} | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

---

## 3.8 `pos_voids`

Completed transaction void event (inventory reversal source).

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `pos_transaction_id` | bigint | null false, FK, unique | One void per txn |
| `store_id` | bigint | null false, FK → stores | |
| `workstation_id` | bigint | null false, FK → workstations | |
| `pos_register_session_id` | bigint | null false, FK | Session at void time |
| `voided_by_user_id` | bigint | null false, FK → users | |
| `pos_authorization_id` | bigint | nullable, FK | |
| `voided_at` | datetime | null false | |
| `business_date` | date | null false | From session at void |
| `reason_code` | string | nullable | Controlled |
| `notes` | text | nullable | |
| `created_at` | datetime | null false | |
| `updated_at` | datetime | null false | |

### Inventory linkage

Void inventory posting:

```text
inventory_postings.posting_type = pos_void
inventory_postings.source_type = PosVoid
inventory_postings.source_id = pos_voids.id
inventory_postings.reversal_of_posting_id = original pos_transaction posting
```

Original posting receives `reversed_by_posting_id`.

---

# 4. Controlled Values Summary

## `pos_register_sessions.status`

```text
open
closed
force_closed
```

## `pos_transactions.status`

```text
draft
suspended
completed
voided
cancelled
```

## `pos_transactions.transaction_type`

```text
sale
return
exchange
```

## `pos_transaction_lines.line_type`

```text
variant
open_ring
```

## `pos_transaction_lines.return_disposition`

```text
return_to_stock
damaged
defective
return_to_vendor_candidate
other
```

## `pos_tenders.tender_type`

```text
cash
card
check
gift_card
store_credit
```

## `pos_cash_movements.movement_type`

```text
paid_in
paid_out
```

---

# 5. Transaction Number Sequence

Implement workstation-scoped sequence via:

- dedicated `pos_workstation_sequences` table, **or**
- `SELECT MAX` with row lock on `(workstation_id)` for completed numbers

Data model doc allows either; migration should pick one and document uniqueness guarantees.

Format:

```text
#{store.store_number}-#{workstation.workstation_number}-#{seq_padded}
```

Pad sequence to fixed width (recommended 6 digits).

---

# 6. Seeds

`db/seeds/phase6_permissions.rb` — idempotent `pos.*` permission keys per functional spec.

Optional: default cashier / lead / manager role permission bundles in seeds or runbook.

No required POS transaction seed data for Phase 6.

---

# 7. Deferred Tables

Do not add in Phase 6:

```text
gift_card_accounts      (superseded by Phase 7B stored_value_accounts)
store_credit_accounts   (superseded by Phase 7B stored_value_accounts)
sale_taxes (normalized tax rows — tax on lines sufficient for Phase 6)
offline_pos_sync_queues
```

See [phase-7b-data-model.md](phase-7b-data-model.md) for the canonical stored value schema.
