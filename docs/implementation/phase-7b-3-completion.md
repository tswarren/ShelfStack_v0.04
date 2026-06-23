# Phase 7B-3 Completion: POS Stored Value Integration

Completed: 2026-06-21

## Summary

Phase 7B-3 wires stored value accounts and ledger into POS settlement so credit can be issued from returns/exchanges, redeemed as tender, voided, and reported.

## Deliverables

### Schema

- `pos_tenders.stored_value_account_id` (FK, nullable)
- `pos_tenders.stored_value_identifier_id` (FK, nullable)

Migration: `db/migrate/20250701120000_add_stored_value_to_pos_tenders.rb`

### Services

```text
Pos::TenderTypePolicy
Pos::StoredValueTenderSupport
Pos::StoredValueAccountResolver
Pos::PostStoredValueLedger
Pos::ReverseStoredValueLedger
```

Hooks:

- `Pos::CompleteTransaction` posts stored value ledger after tender validation
- `Pos::VoidTransaction` reverses stored value ledger after tender reversals

### Permissions (seeded)

```text
pos.tenders.store_credit
pos.tenders.gift_card
pos.refunds.store_credit
```

Reason code: `pos_return_credit`

### UI

- Settlement modal: Store credit / Gift card rows with identifier lookup
- **Store credit refunds:** optional **Generate new identifier** checkbox (default on); creates a redeemable code at completion
- `GET /pos/stored_value_lookup` — masked lookup JSON
- Receipts and completion screen show generated identifier and remaining balance

### Audit events

```text
pos.stored_value.issued
pos.stored_value.redeemed
pos.stored_value.void_reversed
```

## Verification

```bash
./dev/rails-docker bundle exec rails db:migrate
./dev/rails-docker bundle exec rails test test/services/pos/tender_type_policy_test.rb \
  test/services/pos/post_stored_value_ledger_test.rb \
  test/services/pos/reverse_stored_value_ledger_test.rb \
  test/integration/phase7b_pos_stored_value_test.rb
```

Manual smoke: return to store credit → redeem on next sale → void second sale → confirm balance restored.

## Deferred (unchanged)

Check refunds, deposits/prepayments, gift card product activation, buyback intake, multi-store redemption restrictions, GL export.
