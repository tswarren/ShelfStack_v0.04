# Phase 7B Test Plan

Normative specs: [phase-7b-pos-settlement-spec.md](phase-7b-pos-settlement-spec.md), [phase-7b-stored-value-spec.md](phase-7b-stored-value-spec.md)

Data model: [phase-7b-data-model.md](phase-7b-data-model.md)

Roadmap: [phase-7b-customer-credit-foundation.md](../roadmap/phase-7b-customer-credit-foundation.md)

---

# 1. Test categories

| Category | Focus |
| --- | --- |
| Model | `pos_tender` validations, stored value models, controlled enums |
| Service | `SettlementSync`, tender validation, stored value issue/redeem/transfer/void, rebuild/integrity |
| Authorization | `pos.tenders.*`, `stored_value.*`; store scoping |
| Request/controller | POS settlement UI, stored value admin, POS issue/redeem |
| Integration | Multi-tender sale, split refund, issue/redeem/void end-to-end |
| Audit | Settlement and stored value events |
| Migration | `reference_number` backfill, `line_number` assignment |
| Regression | Phase 6 single-tender flows as one-row cases; Phase 7A POS pickup unchanged |

---

# 2. Test layout (planned)

```text
test/models/pos_tender_test.rb                    (extend)
test/models/stored_value_*_test.rb

test/services/pos/settlement_sync_test.rb
test/services/pos/tender_type_policy_test.rb      (7B-3)
test/services/stored_value/issue_test.rb
test/services/stored_value/redeem_credit_test.rb
test/services/stored_value/adjust_test.rb
test/services/stored_value/void_entry_test.rb
test/services/stored_value/transfer_test.rb
test/services/stored_value/rebuild_balances_test.rb
test/services/stored_value/balance_integrity_check_test.rb

test/integration/phase7b_settlement_integration_test.rb
test/integration/phase7b_stored_value_admin_test.rb
test/integration/phase7b_pos_stored_value_integration_test.rb

test/support/phase7b_test_helper.rb
db/seeds/phase7b_permissions.rb
```

---

# 3. 7B-1 key scenarios

## Settlement sync

1. Sale with multiple card rows sums to total
2. Sale with multiple check rows sums to total
3. Sale with cash + cards + checks; cash over-tender sets `tendered_cents` and `change_cents`
4. Only one cash row; second cash add replaces first
5. Card row requires `card_brand`; rejects missing brand
6. `card_last_four` validates four digits when present
7. Non-cash rows cannot exceed remaining balance
8. Return with cash + card split refunds sums to negative total
9. Check refund row rejected
10. Zero-total exchange completes without tender rows
11. `line_number` unique per transaction; stable through suspend/resume
12. Line change after tenders shows remaining mismatch in readiness preview

## Migration

13. Backfill `tendered_cents:` reference_number into structured fields
14. Existing completed transactions remain valid after migration

## Void and receipts

15. Void creates reversing row per original with copied card/check fields
16. Receipt lists each tender row; cash tendered/change aggregate correct
17. Register reports break card by brand; check payment detail list

## Authorization

18. Cash refund over threshold requires authorization (total across cash rows)

## Audit

19. `pos.settlement.synced` on draft sync; void reversal audited

## Regression

20. Single cash-only sale still completes (one-row degenerate case)

---

# 4. 7B-2 key scenarios

## Accounts

1. Create customer-linked account
2. Create standalone account with holder snapshot
3. Suspend/close account; block redeem when inactive

## Identifiers

4. Generate identifier with check digit; unique among active
5. Manual entry normalized to digest
6. Deactivate identifier; replacement chain preserved
7. Masked display in UI (no full value in response body)

## Ledger

8. Manual issue increases balance; ledger entry append-only
9. Adjust with reason code; negative adjust cannot go below zero
10. Void entry creates reversing entry; original unchanged
11. Transfer creates paired entries; liability total unchanged
12. Concurrent redeem: second fails when balance insufficient (lock)

## Balance integrity

13. `RebuildBalances` fixes drifted `current_balance_cents`
14. `BalanceIntegrityCheck` detects mismatch

## Permissions and audit

15. Issue without `stored_value.issue` denied
16. Audit events on account and ledger lifecycle

## Scope boundary

17. No POS tender rows created in 7B-2-only tests

---

# 5. 7B-3 key scenarios

## Issuance

1. Return with customer issues store credit; customer-linked account credited
2. Return without customer creates/selects bearer account
3. Exchange split: card refund + store credit issue on same transaction
4. Issuance creates negative `pos_tender` and positive ledger `issue` entry linked via `source`

## Redemption

5. Redeem store credit on sale; balance decreases
6. Redeem multiple accounts in one transaction
7. Redeem exceeds balance rejected
8. Redeem exceeds amount due rejected
9. `gift_card` account type redeems with `gift_card` tender type

## Policy

10. `store_credit` tender rejected before 7B-3 policy enabled
11. Tender without `stored_value_account_id` rejected

## Completion and void

12. Completion rolls back if ledger post fails
13. Void reverses ledger entries with `reverses_entry_id`
14. Void reverses `pos_tender` rows

## Receipts and reports

15. Receipt shows issued/redeemed amount and remaining balance
16. Register report includes store credit and gift card totals
17. Liability report reflects POS activity

## Gift card sale (7B-3 enhancement)

18. `/giftcard 25` adds `gift_card_sale` line; cash payment; completion issues `pos_gift_card_sale` ledger entry
19. Generate identifier on new card; receipt shows code; void reverses balance
20. Reload via identifier lookup increases existing `gift_card` account balance
21. Completion blocked when gift card line lacks activation metadata
22. `pos.gift_cards.issue` required; distinct from `pos.tenders.gift_card` redeem permission
23. Void reverses line-sourced gift card sale ledger entries
24. Register report separates gift card redemptions (tender) and gift card sales (lines)

## Receipts, slips, and balance inquiry (7B-3 follow-up)

25. Gift card sale receipt line shows card number, value/reload amount, and new balance
26. Issuance slip prints full identifier, value, and new balance for gift card sale and store credit issue
27. Issuance slip reprint records `pos.stored_value_slip.printed` audit event
28. `/balance` command opens balance inquiry panel; masked balance returned
29. POS menu Check Balance page renders for authorized cashiers
30. Balance inquiry lookup accepts gift card and store credit accounts via `purpose=balance_inquiry`

---

# 6. Always test

- Permission checks
- Store-scoped access where applicable
- Audit event creation on meaningful mutations
- Seed idempotency for Phase 7B permissions and reason codes
- Void does not mutate original tenders or ledger entries

---

# 7. Manual smoke (post-implementation)

**7B-1**

1. Complete sale with two cards and one check
2. Complete return with card + cash refund split
3. Void transaction; verify tender reversals on receipt

**7B-2**

4. Create account, issue credit, transfer to second account, run integrity check

**7B-3**

5. Return to store credit; redeem on next sale; void second sale and confirm balance restored
6. Sell gift card; print issuance slip; confirm full card number on slip and new balance on receipt
7. Check balance from POS menu and `/balance` command; confirm masked number only

---

# 8. Deferred test areas

```text
check refunds
deposits/prepayments
buyback trade credit issuance from intake
multi-store redemption restrictions
GL export
```
