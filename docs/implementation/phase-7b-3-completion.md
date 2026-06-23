# Phase 7B-3 Completion: POS Stored Value Integration

Completed: 2026-06-21

## Summary

Phase 7B-3 wires stored value accounts and ledger into POS settlement so credit can be issued from returns/exchanges, redeemed as tender, voided, and reported.

## Deliverables

### Schema

- `pos_tenders.stored_value_account_id` (FK, nullable)
- `pos_tenders.stored_value_identifier_id` (FK, nullable)
- `pos_tenders.generate_stored_value_identifier` (boolean, default false)

Migrations:

- `db/migrate/20250701120000_add_stored_value_to_pos_tenders.rb`
- `db/migrate/20250701130000_add_generate_stored_value_identifier_to_pos_tenders.rb`

### Services

```text
Pos::TenderTypePolicy
Pos::StoredValueTenderSupport
Pos::StoredValueAccountResolver
Pos::PostStoredValueLedger
Pos::ReverseStoredValueLedger
Pos::GenerateStoredValueIdentifier
```

Hooks:

- `Pos::CompleteTransaction` posts stored value ledger after tender validation
- `Pos::VoidTransaction` reverses stored value ledger after tender reversals
- `Pos::SettlementSync` resolves accounts, caps redemption amounts, and may generate identifiers before save

### Permissions (seeded)

```text
pos.tenders.store_credit
pos.tenders.gift_card
pos.refunds.store_credit
```

`Seeds::Phase7bPermissions.grant_pos_stored_value_to_roles!` also grants POS roles (`pos_cashier`, `pos_lead`, `pos_manager`):

```text
stored_value.accounts.create
stored_value.identifiers.create
```

Reason code: `pos_return_credit`

Refund store-credit policy accepts any of: `pos.refunds.store_credit`, `pos.tenders.store_credit`, `pos.tenders.refund`, or `pos.transactions.complete` (store-scoped).

### Behavior

**Issuance (returns/exchanges)**

- Customer on transaction: resolve or create customer-linked merchandise-credit account
- No customer: lookup existing identifier/account, or with **Generate new identifier** checked, create a standalone/bearer account and generate a redeemable code at completion

**Redemption (sales)**

- Applied tender amount is `min(amount entered, account balance)` in `Pos::SettlementSync` and settlement UI (Fill / amount clamp)
- Ledger still posts only the saved tender amount; balance cannot go negative
- If capped redemption is less than amount due, another tender (cash/card/check) is required for the remainder

**Settlement form**

- Indexed row params (`settlements[0][tender_type]`, etc.) keep checkbox and amount fields on one row (avoids Rails `settlements[][]` split)

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
./dev/rails-docker bundle exec rails db:seed
./dev/rails-docker bundle exec rails test test/services/pos/tender_type_policy_test.rb \
  test/services/pos/stored_value_tender_support_test.rb \
  test/services/pos/post_stored_value_ledger_test.rb \
  test/services/pos/reverse_stored_value_ledger_test.rb \
  test/services/pos/generate_stored_value_identifier_test.rb \
  test/integration/phase7b_pos_stored_value_test.rb
```

Manual smoke: return to store credit (with generate identifier) → redeem on next sale → void second sale → confirm balance restored.

## 7B-3 enhancement: POS gift card sale (2026-06-21)

Variable-amount gift card issuance at POS (new cards and reloads), paid via normal settlement tenders.

### Schema (`pos_transaction_lines`)

- `stored_value_account_id`, `stored_value_identifier_id`, `generate_stored_value_identifier`
- `line_type` value `gift_card_sale`

### Services

```text
Pos::GiftCardSaleSupport
Pos::GiftCardSalePolicy
Pos::AddGiftCardSaleLine
Pos::UpdateGiftCardSaleLine
Pos::GiftCardSaleAccountResolver
Pos::PostGiftCardSaleLedger
```

Extended: `Pos::GenerateStoredValueIdentifier` (line targets), `Pos::ReverseStoredValueLedger` (line-sourced entries), `Pos::CompletionReadiness`, `Pos::CommandBarRouter` (`/giftcard`).

### Permission

```text
pos.gift_cards.issue
```

Reason code: `pos_gift_card_sale`

### Behavior

- `/giftcard 25` or gift card drawer adds a `gift_card_sale` line; activation via scan (reload) or generate-new checkbox
- Completion issues ledger credit linked to the line; void reverses
- Register report separates **Gift Card Redemptions** (tender) vs **Gift Card Sales** (lines)

## 7B-3 follow-up: receipts, issuance slips, balance inquiry (2026-06-21)

### Receipt enhancements

- Gift card sale lines on main receipt: card number, value/reload amount, new balance
- Store credit issue tenders label balance as **New balance**

### Issuance slip

```text
Pos::StoredValueIssuanceSlips
Pos::StoredValueIssuanceSlipPresenter
Pos::StoredValueIssuanceSlipsController
GET /pos/stored_value_issuance_slips/:id
```

Print links on completion screen and receipt actions. Audit: `pos.stored_value_slip.printed`.

### Balance inquiry

```text
/balance command -> inline panel
GET /pos/stored_value_balance
GET /pos/stored_value_lookup?purpose=balance_inquiry
```

POS menu **Check Balance** when register is open.

## Deferred (unchanged)

Check refunds, deposits/prepayments, product SKU gift card catalog workflow, buyback intake, multi-store redemption restrictions, GL export.
