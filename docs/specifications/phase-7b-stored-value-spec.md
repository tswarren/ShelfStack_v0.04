# Phase 7B Stored Value Specification

Normative behavior for slices **7B-2** and **7B-3**. Parent: [phase-7b-customer-credit-foundation.md](../roadmap/phase-7b-customer-credit-foundation.md). Data model: [phase-7b-data-model.md](phase-7b-data-model.md).

---

# 1. Scope

## 7B-2 (foundation)

Stored value accounts, identifiers, append-only ledger, transfers, manual operations, liability reporting, permissions, audit.

## 7B-3 (POS integration)

Issue credit from returns/exchanges, redeem as POS tender, void reversal, receipts, register reports.

## Deferred (entire phase)

```text
customer deposits / prepayments
gift card product SKU / catalog sale workflow (POS variable-amount sale implemented)
buyback intake and pricing
multi-store liability settlement
GL / accounting export
check refunds on POS
```

---

# 2. Canonical model

Supersedes deferred `gift_card_accounts` and `store_credit_accounts` from Phase 6 documentation.

```text
stored_value_accounts
stored_value_identifiers
stored_value_ledger_entries
stored_value_transfers
stored_value_reason_codes
```

---

# 3. Account types

## 3.1 Stored value account types

```text
merchandise_credit
trade_credit
gift_card
promo_credit
legacy_credit
manual_store_credit
```

`trade_credit` is supported structurally for future buyback; buyback workflows are out of scope.

## 3.2 POS tender type mapping

| POS `tender_type` | Allowed account types |
| --- | --- |
| `store_credit` | `merchandise_credit`, `trade_credit`, `promo_credit`, `legacy_credit`, `manual_store_credit` |
| `gift_card` | `gift_card` |

---

# 4. Account rules

| Rule | Detail |
| --- | --- |
| `issuing_store_id` | Required |
| `customer_id` | Nullable; links to `customers.id` only (not snapshot-only request data) |
| `holder_name_snapshot` | Optional for standalone/legacy |
| `current_balance_cents` | Cached; ledger is authoritative |
| Negative balance | Not allowed |
| `active` | Prefer inactivation over hard delete when referenced |

## 4.1 Redemption scope (7B)

No `redeemable_store_scope` column in 7B. Redemption is allowed at any store. Activity `store_id` on ledger entries records where redemption occurred.

---

# 5. Identifier rules

| Capability | Rule |
| --- | --- |
| Manual entry | Staff-entered codes normalized and validated |
| System generation | Randomized, non-sequential, check-digit validated |
| Storage | Store digest/token for lookup; mask display in UI |
| Security | Full identifier values not logged or shown in normal UI |
| Replace/deactivate | Deactivate lost identifiers; history preserved |
| Uniqueness | Active identifier values unique among active identifiers |

---

# 6. Ledger rules

## 6.1 Append-only

Posted ledger entries are never edited. Corrections use reversing entries.

## 6.2 Entry types

```text
issue
redeem
adjust
transfer_out
transfer_in
void_reversal
```

## 6.3 Required fields

```text
stored_value_account_id
store_id
entry_type
amount_delta_cents  (signed; issue positive, redeem negative)
posted_at
created_by_user_id
reason_code_id      (required for manual issue, adjust, transfer, void)
```

## 6.4 Reversal

```text
reverses_entry_id on reversing entry
original entry unchanged
account balance updated from reversing delta
```

## 6.5 Concurrency

Account row locked before balance check and post. Two concurrent redemptions cannot exceed balance.

## 6.6 Cached balance

`StoredValue::RebuildBalances` and `StoredValue::BalanceIntegrityCheck` mirror inventory patterns.

Rake tasks:

```text
rails shelfstack:stored_value:rebuild_balances
rails shelfstack:stored_value:integrity_check
```

---

# 7. Transfers

Transfer between accounts creates paired entries:

```text
transfer_out on source (negative delta)
transfer_in on destination (positive delta)
stored_value_transfers header links the pair
```

Total outstanding liability unchanged. Reason code required.

---

# 8. Manual operations (7B-2)

| Operation | Service (suggested) | Permission |
| --- | --- | --- |
| Issue | `StoredValue::Issue` | `stored_value.issue` |
| Adjust | `StoredValue::Adjust` | `stored_value.adjust` |
| Void entry | `StoredValue::VoidEntry` | `stored_value.void` |
| Transfer | `StoredValue::Transfer` | `stored_value.transfer` |

All require reason code and audit events.

---

# 9. Liability reporting (7B-2)

Operational reports only:

```text
outstanding balance by account type and issuing store
activity: issue, redeem, adjust, void, transfer
```

Not GL journal entries or export.

Permission: `stored_value.reports.view`.

---

# 10. POS integration (7B-3)

## 10.1 Tender type policy

```text
Pos::TenderTypePolicy.allowed_types(transaction)
```

7B-1: `cash`, `card`, `check`

7B-3 adds: `store_credit`, `gift_card` when stored value validation passes.

## 10.2 `pos_tenders` linkage

For `store_credit` / `gift_card` rows:

```text
stored_value_account_id   required
stored_value_identifier_id required when lookup by code
```

## 10.3 Issuance

Return or exchange with refund due:

```text
pos_tender.amount_cents negative (refund settlement)
ledger entry_type issue, amount_delta_cents positive
source_type PosTender, source_id pos_tender.id
```

### Account selection

| Scenario | Behavior |
| --- | --- |
| Customer on transaction | Default customer-linked account; create if missing (permission-gated) |
| No customer | Select or create standalone/bearer account |
| Split refund | Store credit row coexists with card/cash refund rows |

## 10.4 Redemption

```text
pos_tender.amount_cents positive
ledger entry_type redeem, amount_delta_cents negative
one tender row + one ledger entry per account
POS saves min(amount entered, account balance) on the tender row
redemption cannot exceed remaining transaction amount due (tender total must match transaction total)
multiple accounts per transaction allowed
```

When the cashier enters more than the account balance, settlement caps the tender to the available balance rather than rejecting the row. Any remaining amount due requires another tender type.

## 10.5 Completion transaction boundary

```text
recalculate -> validate tenders -> validate stored value -> lock accounts
-> post ledger entries -> complete POS -> receipt -> commit
```

Failure rolls back entire completion.

## 10.7 Gift card sale (7B-3 enhancement)

Gift card **sale/reload** uses a `gift_card_sale` POS line, not a `gift_card` settlement tender.

```text
/giftcard <amount>  -> add gift_card_sale line
scan existing card  -> reload (issue to existing gift_card account)
generate identifier -> new bearer gift_card account + identifier at completion
pay with cash/card/check tenders
```

At completion:

```text
ledger entry_type issue, reason_code pos_gift_card_sale
source_type PosTransactionLine
```

Permission: `pos.gift_cards.issue` (distinct from `pos.tenders.gift_card` redemption).

## 10.8 Receipts, issuance slips, and balance inquiry

### Sales receipt

- Gift card sale lines show full card number, issue/reload amount, and **new balance** after completion
- Store credit issue tenders show **New balance** (redemption tenders show **Remaining balance**)

### Issuance slip

Separate 80mm printable document per issuance event:

| Source | When |
| --- | --- |
| `gift_card_sale` line | Every completed gift card sale or reload |
| `store_credit` issue tender | Return/exchange credit issuance |

Slip shows store header, transaction meta, document title (`GIFT CARD` / `STORE CREDIT`), full formatted identifier, value, new balance, and legal footer. Manual print from completion screen, receipt actions, or `GET /pos/stored_value_issuance_slips/:ledger_entry_id`. Reprint audits `pos.stored_value_slip.printed`.

### Balance inquiry

| Entry | Behavior |
| --- | --- |
| `/balance` command | Opens inline panel during transaction edit |
| POS menu **Check Balance** | `GET /pos/stored_value_balance` |
| Lookup | `GET /pos/stored_value_lookup?purpose=balance_inquiry` — masked identifier + balance only |

Auth: any of `pos.tenders.gift_card`, `pos.tenders.store_credit`, `pos.gift_cards.issue`.

## 10.6 Void

After inventory and tender reversals, create reversing ledger entries with `reverses_entry_id`. Do not mutate original entries.

---

# 11. Permissions

## 7B-2

```text
stored_value.accounts.view
stored_value.accounts.create
stored_value.accounts.update
stored_value.accounts.suspend
stored_value.accounts.close
stored_value.identifiers.create
stored_value.identifiers.replace
stored_value.identifiers.deactivate
stored_value.ledger.view
stored_value.issue
stored_value.adjust
stored_value.void
stored_value.transfer
stored_value.reports.view
```

## 7B-3

```text
pos.tenders.store_credit
pos.tenders.gift_card
pos.refunds.store_credit
pos.gift_cards.issue
```

---

# 12. Audit events

## Accounts and identifiers

```text
stored_value.account.created
stored_value.account.updated
stored_value.account.suspended
stored_value.account.closed
stored_value.identifier.created
stored_value.identifier.replaced
stored_value.identifier.deactivated
```

## Ledger

```text
stored_value.ledger.issued
stored_value.ledger.redeemed
stored_value.ledger.adjusted
stored_value.ledger.voided
stored_value.ledger.transferred
```

## POS (7B-3)

```text
pos.stored_value.issued
pos.stored_value.redeemed
pos.stored_value.void_reversed
```

---

# 13. UI placement

| Surface | 7B-2 | 7B-3 |
| --- | --- | --- |
| Customers workspace | Account list/detail, manual issue/adjust/transfer | — |
| Setup | Reason codes | — |
| POS transaction | — | Issue/redeem panels, settlement row types |

---

# 14. Exit criteria

See slice roadmaps:

- [phase-7b-2-stored-value-foundation.md](../roadmap/phase-7b-2-stored-value-foundation.md)
- [phase-7b-3-pos-stored-value-integration.md](../roadmap/phase-7b-3-pos-stored-value-integration.md)
