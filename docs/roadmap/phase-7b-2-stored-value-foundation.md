# 7B-2: Stored Value Foundation

Parent phase: [phase-7b-customer-credit-foundation.md](phase-7b-customer-credit-foundation.md)

Normative spec: [phase-7b-stored-value-spec.md](../specifications/phase-7b-stored-value-spec.md)

## Purpose

7B-2 adds the stored value account and ledger foundation **without POS integration**. POS issue/redeem belongs to 7B-3.

It answers:

> How does ShelfStack track merchandise credit, trade credit, promo credit, legacy credit, and gift-card-style balances as operational liabilities with auditable ledger history?

## Tables

```text
stored_value_accounts
stored_value_identifiers
stored_value_ledger_entries
stored_value_transfers
stored_value_reason_codes
```

This model **supersedes** earlier deferred `gift_card_accounts` and `store_credit_accounts` language.

## In scope

```text
customer-linked and standalone/bearer accounts
manual credit issuance
manual adjustment
void/reversal workflow
balance transfer between accounts
identifier generation and manual entry
balance lookup
operational liability reporting
permissions and audit events
cached balance with rebuild/integrity check
```

## Out of scope

```text
POS return-to-credit
POS stored value redemption
gift card activation/sale product workflow
used buyback intake, pricing, seller workflow
customer deposits/prepayments
multi-store liability settlement
GL journal entries
```

## Account types

Stored value account types (not POS tender types):

```text
merchandise_credit
trade_credit
gift_card
promo_credit
legacy_credit
manual_store_credit
```

Avoid plain `store_credit` as an account type.

POS tender types remain `store_credit` and `gift_card` (Phase 6 enum). Mapping:

| POS tender type | Stored value account types |
| --- | --- |
| `store_credit` | `merchandise_credit`, `trade_credit`, `promo_credit`, `legacy_credit`, `manual_store_credit` |
| `gift_card` | `gift_card` |

## `trade_credit` without buyback

`trade_credit` is structurally supported so future buyback credit can use the same ledger. 7B-2 does not implement buyback workflows. Manual issue of `trade_credit` may be allowed for testing, migration, or manager correction.

## Ledger rules

```text
ledger is append-only
posted entries are never edited
balance is ledger-derived
stored_value_accounts.current_balance_cents is cached, not authoritative
negative balances are not allowed
issue/redeem/adjust/transfer/void operations lock the account row
each entry records created_by_user_id and posted_at
reason code required for manual issue, adjustment, transfer, and void
```

Reversal model (mirror POS tenders):

```text
stored_value_ledger_entries.reverses_entry_id
voiding creates a new reversing entry; original unchanged
```

## Concurrency

```text
StoredValue::RedeemCredit (and POS redemption in 7B-3) locks the account before checking balance
two registers cannot redeem the same bearer code beyond its balance
```

## Identifier rules

```text
manual entry
system generation (randomized, non-sequential, check-digit validated)
legacy import
replacement/deactivation without deleting history
masked display in UI
lookup by normalized digest/token — full values not shown in normal UI or logs
```

## Store scope

```text
stored_value_accounts.issuing_store_id required
stored_value_ledger_entries.store_id required
Phase 7B: redemption allowed at any store (no restriction column)
liability reporting groups by issuing store and activity store
multi-store liability settlement deferred
```

## Customer linkage

```text
stored_value_accounts.customer_id nullable
customer-linked accounts reference customers.id (not Phase 7A snapshot-only data)
standalone/bearer accounts omit customer_id
holder_name_snapshot allowed for standalone/legacy accounts
```

## Cached balance integrity

```text
StoredValue::RebuildBalances
StoredValue::BalanceIntegrityCheck
rails shelfstack:stored_value:rebuild_balances
rails shelfstack:stored_value:integrity_check
```

Mirrors inventory balance patterns.

## Permissions

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

POS tender permissions deferred to 7B-3:

```text
pos.tenders.store_credit
pos.tenders.gift_card
pos.refunds.store_credit
```

## Liability reporting

Operational reports only — outstanding balances, issuance, redemption, adjustment, void, transfer activity. **No GL journal entries or accounting export.**

## Audit events (summary)

```text
stored_value.account.created
stored_value.account.updated
stored_value.account.suspended
stored_value.account.closed
stored_value.identifier.created
stored_value.identifier.replaced
stored_value.identifier.deactivated
stored_value.ledger.issued
stored_value.ledger.adjusted
stored_value.ledger.voided
stored_value.ledger.transferred
```

Full list in [phase-7b-stored-value-spec.md](../specifications/phase-7b-stored-value-spec.md).

## Workspace

Stored value account administration belongs in **Customers** workspace (`/customers`) or **Setup** for reason codes — detailed in functional spec. POS integration UI is 7B-3.

---

# Exit criteria

7B-2 is complete when:

1. Staff can create a stored value account.
2. Accounts may be customer-linked or standalone/bearer.
3. Staff can manually issue credit with permission and reason code.
4. Staff can adjust a balance with permission and reason code.
5. Staff can void/reverse a ledger entry without mutating the original.
6. Staff can transfer part or all of a balance between accounts.
7. Transfers create paired transfer-out and transfer-in entries.
8. Transfers do not change total outstanding liability.
9. Identifiers can be manually entered or system-generated.
10. Generated identifiers are randomized and check-digit validated.
11. Lost/replaced identifiers can be deactivated without deleting history.
12. Account balances are traceable to ledger entries.
13. Rebuild and integrity-check tasks work.
14. Outstanding liability reporting is available (operational, not GL).
15. Stored value actions are permission-controlled and audited.
16. No POS return-credit or redemption behavior is required to complete 7B-2.
