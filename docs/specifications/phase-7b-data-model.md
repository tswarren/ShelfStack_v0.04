# Phase 7B Data Model

Normative specs: [phase-7b-pos-settlement-spec.md](phase-7b-pos-settlement-spec.md), [phase-7b-stored-value-spec.md](phase-7b-stored-value-spec.md)

Roadmap: [phase-7b-customer-credit-foundation.md](../roadmap/phase-7b-customer-credit-foundation.md)

---

# 1. Schema supersession

Phase 7B replaces earlier future-table language:

```text
gift_card_accounts      -> superseded by stored_value_accounts (account_type gift_card)
store_credit_accounts   -> superseded by stored_value_accounts (merchandise_credit, etc.)
```

POS continues to use `pos_tenders.tender_type` values `store_credit` and `gift_card`.

---

# 2. Changes to `pos_tenders` (7B-1)

## 2.1 New columns

| Column | Type | Nullable | Notes |
| --- | --- | --- | --- |
| `line_number` | integer | not null | Unique per transaction |
| `tendered_cents` | integer | yes | Cash over-tender |
| `change_cents` | integer | yes | Cash change due |
| `card_brand` | string | yes | Required when `tender_type = card` |
| `card_last_four` | string | yes | 4 digits if present |
| `card_authorization_code` | string | yes | |
| `check_number` | string | yes | Payment only in 7B-1 |
| `notes` | text | yes | Staff/internal |

## 2.2 Unchanged columns

| Column | Notes |
| --- | --- |
| `tender_type` | `cash`, `card`, `check`, `gift_card`, `store_credit` |
| `amount_cents` | Applied settlement amount |
| `reference_number` | Legacy/reserved; no new cash tendered encoding |
| `reverses_tender_id` | Void reversal FK |

## 2.3 Indexes

```text
unique (pos_transaction_id, line_number)
index (pos_transaction_id)
index (reverses_tender_id)
```

## 2.4 Controlled values: `card_brand`

```text
visa
mastercard
american_express
discover
debit
other
```

## 2.5 Migration backfill

For existing `cash` tenders with `reference_number` matching `tendered_cents:%`:

```text
tendered_cents = parsed value
change_cents = max(tendered_cents - amount_cents, 0)
reference_number = NULL
```

Assign `line_number` sequentially per transaction for existing rows.

---

# 3. Changes to `pos_tenders` (7B-3)

| Column | Type | Nullable | Notes |
| --- | --- | --- | --- |
| `stored_value_account_id` | bigint FK | yes | Required when tender_type in store_credit, gift_card |
| `stored_value_identifier_id` | bigint FK | yes | Required when redemption lookup uses identifier |

---

# 4. `stored_value_reason_codes`

| Column | Type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | bigint | | PK |
| `reason_key` | string | not null | Stable key, unique |
| `name` | string | not null | Display |
| `description` | text | yes | |
| `active` | boolean | not null | default true |
| `created_at` / `updated_at` | datetime | | |

Seeds: idempotent by `reason_key`.

---

# 5. `stored_value_accounts`

| Column | Type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | bigint | | PK |
| `issuing_store_id` | bigint FK stores | not null | |
| `customer_id` | bigint FK customers | yes | Real customer only |
| `account_type` | string | not null | See §5.1 |
| `holder_name_snapshot` | string | yes | Standalone/legacy |
| `current_balance_cents` | integer | not null | Cached; default 0 |
| `active` | boolean | not null | default true |
| `notes` | text | yes | Staff |
| `created_at` / `updated_at` | datetime | | |

## 5.1 `account_type`

```text
merchandise_credit
trade_credit
gift_card
promo_credit
legacy_credit
manual_store_credit
```

## 5.2 Indexes

```text
index (issuing_store_id)
index (customer_id)
index (account_type)
```

---

# 6. `stored_value_identifiers`

| Column | Type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | bigint | | PK |
| `stored_value_account_id` | bigint FK | not null | |
| `identifier_type` | string | not null | `manual`, `generated`, `legacy_import` |
| `display_value_masked` | string | yes | UI display |
| `lookup_digest` | string | not null | Normalized lookup; unique among active |
| `active` | boolean | not null | default true |
| `replaced_by_identifier_id` | bigint FK self | yes | |
| `created_at` / `updated_at` | datetime | | |

Full raw identifier values are not stored in plain text in operational columns; generation/validation logic in services.

---

# 7. `stored_value_ledger_entries`

| Column | Type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | bigint | | PK |
| `stored_value_account_id` | bigint FK | not null | |
| `store_id` | bigint FK stores | not null | Activity store |
| `entry_type` | string | not null | See §7.1 |
| `amount_delta_cents` | integer | not null | Signed |
| `balance_after_cents` | integer | yes | Snapshot optional |
| `reason_code_id` | bigint FK | yes | Required for manual ops |
| `reverses_entry_id` | bigint FK self | yes | |
| `source_type` | string | yes | Polymorphic, e.g. PosTender |
| `source_id` | bigint | yes | |
| `notes` | text | yes | |
| `posted_at` | datetime | not null | |
| `created_by_user_id` | bigint FK users | not null | |
| `created_at` / `updated_at` | datetime | | |

## 7.1 `entry_type`

```text
issue
redeem
adjust
transfer_out
transfer_in
void_reversal
```

## 7.2 Indexes

```text
index (stored_value_account_id, posted_at)
index (store_id, posted_at)
index (source_type, source_id)
index (reverses_entry_id)
```

---

# 8. `stored_value_transfers`

| Column | Type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | bigint | | PK |
| `from_account_id` | bigint FK | not null | |
| `to_account_id` | bigint FK | not null | |
| `amount_cents` | integer | not null | Positive |
| `transfer_out_entry_id` | bigint FK ledger | not null | |
| `transfer_in_entry_id` | bigint FK ledger | not null | |
| `reason_code_id` | bigint FK | not null | |
| `created_by_user_id` | bigint FK | not null | |
| `created_at` / `updated_at` | datetime | | |

---

# 9. Seeds

```text
db/seeds/phase7b_permissions.rb
db/seeds/data/stored_value_reason_codes.csv  (optional)
```

Idempotent permission and reason code seeds.

---

# 10. Deferred tables

Do not add in Phase 7B:

```text
gift_card_accounts
store_credit_accounts
customer_deposit_accounts
gl_journal_entries
pos_tenders.metadata
```

---

# 11. Foreign key summary

```text
pos_tenders.stored_value_account_id -> stored_value_accounts.id
pos_tenders.stored_value_identifier_id -> stored_value_identifiers.id
pos_tenders.reverses_tender_id -> pos_tenders.id

stored_value_accounts.issuing_store_id -> stores.id
stored_value_accounts.customer_id -> customers.id

stored_value_identifiers.stored_value_account_id -> stored_value_accounts.id

stored_value_ledger_entries.stored_value_account_id -> stored_value_accounts.id
stored_value_ledger_entries.store_id -> stores.id
stored_value_ledger_entries.reverses_entry_id -> stored_value_ledger_entries.id
stored_value_ledger_entries.reason_code_id -> stored_value_reason_codes.id
stored_value_ledger_entries.created_by_user_id -> users.id
```
