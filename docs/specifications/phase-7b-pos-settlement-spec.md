# Phase 7B POS Settlement Specification

Normative behavior for slice **7B-1**. Parent: [phase-7b-customer-credit-foundation.md](../roadmap/phase-7b-customer-credit-foundation.md). Data model: [phase-7b-data-model.md](phase-7b-data-model.md).

---

# 1. Scope

7B-1 upgrades POS settlement to support multiple `pos_tender` rows per transaction with structured cash, card, and check reference data.

**In scope:** sales, returns, exchanges (signed totals), void tender reversal field copy, receipts, register reports, `Pos::SettlementSync`.

**Out of scope:** `store_credit` / `gift_card` tenders (7B-3), check refunds, `metadata` JSONB on tenders, GL export.

---

# 2. Settlement row model

## 2.1 Core rule

```text
sum(pos_tenders.amount_cents) == pos_transactions.total_cents
```

Completed transactions must satisfy this before completion.

## 2.2 Row limits

| Tender type | Max rows per transaction (7B-1) |
| --- | --- |
| `cash` | 1 (edit/replace on re-add) |
| `card` | unlimited |
| `check` | unlimited |
| `store_credit` | 0 (7B-3) |
| `gift_card` | 0 (7B-3) |

## 2.3 `line_number`

- Required, positive integer
- Unique per `pos_transaction_id`
- Assigned at row creation
- Preserved through suspend/resume
- Draft deletes may renumber remaining rows
- Completed transactions never renumber
- Void reversal rows reference original ordering (copy `line_number` or link via `reverses_tender_id`)

---

# 3. Field rules

## 3.1 All rows

| Field | Rule |
| --- | --- |
| `tender_type` | Required; Phase 7B-1 allows `cash`, `card`, `check` only |
| `amount_cents` | Required integer; sign matches sale vs refund |
| `line_number` | Required |
| `notes` | Optional; staff/internal only; not on customer receipt |

## 3.2 Cash

| Field | Rule |
| --- | --- |
| `amount_cents` | Applied cash (positive on sale, negative on refund) |
| `tendered_cents` | Required when customer tendered differs from applied amount |
| `change_cents` | Required/calculated when over-tendered: `tendered_cents - amount_cents` |

Example sale:

```text
total due: $18.75
cash tendered: $20.00
amount_cents: 1875
tendered_cents: 2000
change_cents: 125
```

## 3.3 Card

| Field | Rule |
| --- | --- |
| `tender_type` | Always `card` |
| `card_brand` | Required: `visa`, `mastercard`, `american_express`, `discover`, `debit`, `other` |
| `card_last_four` | Optional; exactly four digits if present |
| `card_authorization_code` | Optional |
| Full PAN | Never stored |

## 3.4 Check (payment only)

| Field | Rule |
| --- | --- |
| `check_number` | Optional |
| Bank routing/account | Never stored in 7B |

Check **refund** rows are rejected in 7B-1.

## 3.5 `reference_number`

- Retained for legacy compatibility
- Must not store cash tendered after migration
- New integrations must not use without explicit spec amendment

---

# 4. Transaction-type behavior

## 4.1 Sale (`total_cents > 0`)

- Tender rows positive
- Non-cash sum must not exceed total
- Cash fills remainder; may over-tender
- Multiple card and check rows allowed

## 4.2 Return / refund due (`total_cents < 0`)

- Tender rows negative
- Multiple rows allowed (cash + card split)
- **Behavior change from Phase 6:** cash refund no longer required to be a single row matching full due
- Card refunds require `card_brand`
- Check refunds rejected

## 4.3 Even exchange (`total_cents == 0`)

- No tender rows required
- Receipt prints normally

---

# 5. Draft, suspend, and completion

- Settlement rows may be added/edited/removed while transaction is `draft` or `suspended`
- Suspend preserves rows; resume shows same list
- Line changes after tenders entered: UI shows remaining due, over-tender, or refund mismatch
- Completion runs `Pos::SettlementSync` validation then `Pos::TenderValidator`

## 5.1 Cash refund authorization

Total cash refund across all cash rows:

```text
if abs(sum(cash refund amount_cents)) > threshold:
  require pos_authorization cash_refund_over_threshold
```

Threshold and permission unchanged from Phase 6.

---

# 6. Services

## 6.1 `Pos::SettlementSync`

Replaces `Pos::TenderSync` for row-based settlement.

Responsibilities: parse inputs, validate direction and required fields, calculate cash change, assign `line_number`, upsert/delete rows (not blind destroy-all), return remaining due and change due.

`Pos::TenderSync` may remain as a thin wrapper during migration; remove when callers are migrated.

## 6.2 `Pos::TenderValidator`

Continues to validate tender total and Phase 6 cash refund threshold.

7B-3 extends allowed types via `Pos::TenderTypePolicy` (not in 7B-1).

---

# 7. Void behavior

On completed void, for each original tender where `reverses_tender_id` is nil:

```text
create reversing pos_tender
amount_cents = -original.amount_cents
reverses_tender_id = original.id
copy: tender_type, card_brand, card_last_four, card_authorization_code, check_number, notes
```

Cash drawer math uses reversal `amount_cents`. `tendered_cents` / `change_cents` on reversal rows are optional display-only.

Audit: `pos.settlement.void_reversed`.

---

# 8. Receipts

- List each non-reversal tender row with type, details, and amount
- Show aggregate cash applied, cash tendered, and change due
- Do not show `notes`

Update helpers: `pos_receipt_change_cents`, `pos_tender_receipt_label`, `pos_tender_receipt_amount_cents` to aggregate cash rows safely.

---

# 9. Reports

Update:

- `Pos::SalesRegisterSummaryReport`
- `Pos::SalesRevenueSummaryReport`
- `Pos::RegisterSessionSummary` (cash drawer: sum cash `amount_cents` only)
- Session/register views and void display

Summaries include:

```text
cash payments / cash refunds
card payments and refunds by card_brand
check payments (not check refunds in 7B-1)
check detail list (number + amount)
```

---

# 10. Permissions

Use existing POS tender permissions for cash/card/check. No row-level tender permissions in 7B-1.

Optional additions: `pos.tenders.manage`, `pos.refunds.cash`, `pos.refunds.card`.

---

# 11. Audit events

| Event | When |
| --- | --- |
| `pos.settlement.row_added` | Settlement row created (optional batch via synced) |
| `pos.settlement.row_updated` | Row fields changed |
| `pos.settlement.row_removed` | Row deleted in draft |
| `pos.settlement.synced` | Settlement sync completed on draft |
| `pos.settlement.validation_failed` | Completion blocked by settlement validation |
| `pos.settlement.cash_change_recorded` | Cash over-tender with change |
| `pos.settlement.void_reversed` | Void created tender reversals |

---

# 12. Migration

Backfill rule for existing cash tenders:

```text
IF tender_type = cash
AND reference_number LIKE 'tendered_cents:%'
THEN
  tendered_cents = parsed integer
  change_cents = max(tendered_cents - amount_cents, 0)
  reference_number = NULL
```

Assign `line_number` to existing rows per transaction (e.g. by `id` order).

---

# 13. Deferred

```text
check refunds
pos_tenders.metadata JSONB
store_credit / gift_card tenders
```
