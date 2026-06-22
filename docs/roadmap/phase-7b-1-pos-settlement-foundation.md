# 7B-1: POS Settlement Foundation

Parent phase: [phase-7b-customer-credit-foundation.md](phase-7b-customer-credit-foundation.md)

Normative spec: [phase-7b-pos-settlement-spec.md](../specifications/phase-7b-pos-settlement-spec.md)

## Purpose

7B-1 upgrades POS settlement so ShelfStack can accurately record real-world payment and refund behavior before stored value is added in 7B-2 and 7B-3.

It answers:

> How does POS record multiple payments or refund settlements, including split card payments, multiple checks, cash with change, and enough reference data for receipts and register reconciliation?

## Core decision

A POS transaction may have **multiple settlement rows**.

Each payment, refund, check, card transaction, or future stored value redemption is represented as its own `pos_tender` row.

```text
Sale total: $86.00

Tenders:
  Cash:              $18.50
  Visa:              $40.00
  Mastercard:        $25.00
  Check #1048:       $2.50
```

Validation sums all tender `amount_cents` against the transaction total.

## Locked decisions

### One cash row per transaction

The UI allows **only one active cash settlement row** per POS transaction. Adding cash again edits/replaces the existing cash row.

Cash change is calculated on that single row:

```text
amount_cents   = applied cash amount
tendered_cents = customer cash tendered (when over-tendered)
change_cents   = tendered_cents - amount_cents
```

Card, check, and future stored value rows may be multiple per transaction.

### Card tender type vs card brand

All credit/debit card payments use `tender_type = "card"`. Brand is separate:

```text
card_brand = visa | mastercard | american_express | discover | debit | other
```

`card_brand` is required for card rows. `card_last_four` (four digits if present) and `card_authorization_code` are optional. Full card numbers are never stored.

### Check refunds out of scope

7B-1 supports **check payments only**, not check refunds. Check refunds are rejected. Future check refunds require a separate store policy/permission (e.g. `pos.refunds.check`).

### No metadata JSONB

7B-1 adds explicit columns only. Do not add a broad `metadata` JSONB field on `pos_tenders`.

### `notes` on tenders

`pos_tenders.notes` is optional, **staff/internal only** — not receipt-visible. Copied to reversal rows for audit context.

### `reference_number` legacy

`reference_number` remains for backward compatibility. New cash/card/check data uses structured fields. Cash tendered must no longer be stored in `reference_number`. Existing `tendered_cents:` values are backfilled (see data model).

### Return tender behavior change

7B-1 **changes** return/refund tender behavior from Phase 6:

```text
multiple negative settlement rows allowed
cash + card split refunds allowed
sum(pos_tenders.amount_cents) == pos_transactions.total_cents
check refunds not allowed
```

This is a behavior change, not only a UI refactor.

### Compatibility wording

Single cash, single card, and single check flows remain supported as ordinary **one-row cases** of the new settlement-row model. The old fixed-field UI and `Pos::TenderSync` destroy-and-recreate behavior are replaced.

### Suspended drafts

Draft and suspended transactions preserve settlement rows. Staff may edit/remove rows after resume while the transaction remains draft. Completion revalidates all rows against the current total. If lines change after tenders were entered, the UI shows remaining due, over-tender warning, or refund mismatch.

### Cash refund authorization

The existing cash refund threshold applies to **total cash refund across the transaction**, not per row. `Pos::TenderValidator` behavior is preserved.

### Permissions

Use existing POS completion/update permissions for cash/card/check settlement editing. Defer `pos.tenders.store_credit` and `pos.tenders.gift_card` to 7B-3.

Optional additions if not already sufficient:

```text
pos.tenders.manage
pos.refunds.cash
pos.refunds.card
```

### Service migration

Introduce `Pos::SettlementSync`. Update controllers/UI to call it. Keep `Pos::TenderSync` temporarily as a compatibility wrapper if needed; remove once all callers are migrated.

### Reports and drawer math

Update:

```text
Pos::SalesRegisterSummaryReport
Pos::SalesRevenueSummaryReport
register/session summary views
receipt tender display helpers
void tender reversal display
```

**Cash drawer uses `amount_cents`, not `tendered_cents`.** Tendered and change are for receipt/audit display.

Register reports in 7B-1 summarize check **payments** only (not check refunds).

---

# Data model additions

Extend `pos_tenders`:

```text
line_number              integer, not null
tendered_cents           integer, nullable
change_cents             integer, nullable
card_brand               string, nullable
card_last_four           string, nullable
card_authorization_code  string, nullable
check_number             string, nullable
notes                    text, nullable
```

Keep: `tender_type`, `amount_cents`, `reference_number`, `reverses_tender_id`.

Unique index: `(pos_transaction_id, line_number)`.

Backfill: if `tender_type = cash` and `reference_number` starts with `tendered_cents:`, parse into `tendered_cents` and `change_cents`, then clear `reference_number`.

Full detail: [phase-7b-data-model.md](../specifications/phase-7b-data-model.md).

---

# Tender behavior

## Sales (`total_cents > 0`)

```text
cash/card/check rows are positive
multiple card rows allowed
multiple check rows allowed
one cash row only; may over-tender
non-cash rows may not exceed remaining balance
sum(pos_tenders.amount_cents) == pos_transactions.total_cents
```

## Returns (`total_cents < 0`)

```text
refund settlement rows are negative
multiple refund rows allowed (cash + card split)
card refund rows require card_brand
check refunds rejected
sum(pos_tenders.amount_cents) == pos_transactions.total_cents
```

## Even exchange (`total_cents == 0`)

```text
no tender rows required
receipt may still print normally
```

---

# UI changes

Replace the fixed “one cash / one card / one check” tender panel with a settlement row list.

Current POS UI renders one field per tender type (`_tender_panel.html.erb`).

## Sale screen (concept)

```text
Amount Due: $86.00

Tenders
------------------------------------------------
Type        Details                     Amount
Cash        Tendered $20.00              $18.50
Visa        ending 1122 / auth 93281     $40.00
Check       #1048                        $27.50

Remaining: $0.00
Change Due: $1.50

[Add Cash] [Add Card] [Add Check]
```

## Return screen (concept)

```text
Refund Due: $42.00

Refunds
------------------------------------------------
Type        Details                     Amount
Card        Visa / auth 883921           $25.00
Cash                                    $17.00

Remaining Refund: $0.00

[Add Cash Refund] [Add Card Refund]
```

---

# Service: `Pos::SettlementSync`

Responsibilities:

```text
parse settlement rows
validate tender/refund direction
validate required fields by tender type
calculate cash change
assign line_number
preserve structured card/check fields
remove rows explicitly marked for deletion
return remaining due/refund and change due
```

---

# Void reversals

For each original tender on void:

```text
create reversing pos_tender
reverses_tender_id = original id
amount_cents = -original.amount_cents
copy: tender_type, card_brand, card_last_four, card_authorization_code, check_number, notes
cash: reversal uses amount_cents for drawer math; tendered_cents/change_cents optional for display
```

---

# Audit events

```text
pos.settlement.row_added
pos.settlement.row_updated
pos.settlement.row_removed
pos.settlement.synced
pos.settlement.validation_failed
pos.settlement.cash_change_recorded
pos.settlement.void_reversed
```

Draft row edits may be summarized through `pos.settlement.synced`. Completed transaction and void-related events should be individually auditable.

---

# Receipts

List each settlement row separately. Aggregate cash (one row in 7B-1):

```text
Tender:
  Visa:              $40.00
  Mastercard:        $25.00
  Check #1048:       $10.00
  Cash:              $11.00

Cash Tendered:       $20.00
Change:               $9.00
```

Helpers should aggregate safely for future multi-cash safety:

```text
cash_applied_cents = sum(cash amount_cents)
cash_tendered_cents = sum(cash tendered_cents where present)
change_cents = sum(cash change_cents)
```

---

# Exit criteria

7B-1 is complete when:

1. POS completes a sale with multiple card tenders.
2. POS completes a sale with multiple check tenders.
3. POS completes a sale with mixed cash, card, and check tenders.
4. POS completes a return with multiple refund settlement rows (cash + card split).
5. Cash over-tender records `tendered_cents` and `change_cents`.
6. Card tenders require `card_brand`.
7. Card tenders may optionally record `card_last_four` and `card_authorization_code`.
8. Check tenders may optionally record `check_number`.
9. Check refunds are rejected.
10. Full card numbers and bank routing/account data are not stored.
11. Receipts show each tender/refund row separately with correct cash tendered/change.
12. Register reports summarize multiple tender rows; card breakdown by brand; check payments listed.
13. Voiding creates reversal rows for each original tender with reference fields copied.
14. Single cash/card/check one-row flows work as degenerate cases of the row model.
15. `reference_number` cash tendered hack is migrated and no longer written.
16. 7B-2/7B-3 can add store credit/gift card tenders without redesigning settlement.
