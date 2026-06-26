# Reporting Semantics

Roadmap: [phase-9a-ux-foundation-for-reporting.md](../roadmap/phase-9a-ux-foundation-for-reporting.md)

Master spec: [phase-9a-ux-foundation-for-reporting-spec.md](phase-9a-ux-foundation-for-reporting-spec.md)

Implementation: `Reports::InclusionRules`, `Reports::ProcurementPathResolver`

---

## Operational vs financial reporting

| Concern | Operational (9b) | Financial (9c) |
| ------- | ------------------ | -------------- |
| Primary source | POS snapshots, ledgers, workflow tables | `financial_entries` / lines |
| Gift card sale | Stored-value ledger; not merchandise revenue | Gift card liability account |
| Sales total | Completed POS transactions | Revenue account postings |
| Inventory value | `inventory_balances` / ledger | Inventory asset postings |
| Reconciliation | POS/register/inventory tie-out | Operational vs financial entries |

Phase 9c posting rules must follow inclusion rules defined here.

---

## Date basis

| Report type | Primary date field |
| ----------- | ------------------ |
| Sales, tax, discount | `business_date` / `completed_at` on completed POS transactions |
| Inventory movement | `occurred_at` on posted ledger entries |
| Audit trails | `created_at` |
| Register summary | Register session open/close boundaries + session `business_date` |
| Stored value activity | `posted_at` on ledger entries |
| Buyback activity | Session completion time / `created_at` per report design |

Reports must state their date basis in header or filter help text.

---

## POS transactions

**Included in sales totals:** `status: completed` only.

**Excluded from sales totals:** `draft`, `cancelled`, `voided`, `suspended` (unless a dedicated audit report).

**Returns/exchanges:** `transaction_type` `return` / `exchange`; cumulative return validation via source line linkage.

**Tax reporting:** use line snapshots — `tax_cents`, `normal_tax_cents`, `applied_tax_source`. Phase 8.5-2a exemptions and 8.5-2b line overrides from application records, not live catalog joins.

**Discount reporting:** Phase 8.5-1 `pos_discount_applications` and allocations; cross-check cached `discount_cents` fields.

**Gift card sale lines:** `line_type: gift_card_sale` — liability activity, not merchandise revenue; non-discountable, non-taxable.

**Gift card / store credit redemption:** tender rows; reduces liability, applies payment.

---

## Register sessions

* Open and closed sessions may appear in operational drawer reports.
* Cash paid in, paid out, drops, and refunds from register cash movement records.
* Expected vs counted cash and over/short from session close data.
* Register summary reconciles session boundaries with completed transaction tenders and movements.

---

## Buybacks

| Status / outcome | Reporting |
| ---------------- | --------- |
| `draft`, `quoted`, `decision` | Excluded from completed buyback totals |
| `completed` | Included; cash/trade credit totals from accepted lines |
| `cancelled`, `voided` | Excluded from activity totals; void reversals separate |
| Rejected lines | Excluded from payout and inventory intake |
| Donated / zero-value lines | No payout; no inventory value inflation |
| `needs_review` | Flag in operational reports |

Inventory intake: posted ledger with `movement_type: used_buyback`, `source: BuybackSession`.

---

## Purchasing and receiving

* PO drafts excluded from submitted-order metrics.
* Receipt reporting uses `quantity_accepted` for inventory impact.
* Inventory value/movement: posted ledger entries only, not unposted PO/receipt drafts.

---

## Customer requests

* Queue reports use workflow status (open, ready for pickup, awaiting customer, awaiting receiving, completed, cancelled).
* Aging from status-appropriate timestamps (document per report in 9b).

---

## Stored value

* Gift card sale → liability increase (not merchandise sales).
* Redemption → liability decrease + payment application.
* Trade credit issuance (buyback) → liability increase.
* Adjustments separately reportable.

---

## Item behavior profiles

Reporting-relevant profiles (derived from product type, tracking, line type):

* New/vendor-order stock
* Used/buyback stock
* Donation/manual stock
* Sideline/vendor-order stock
* Service/fee
* Gift card/stored value
* Digital/non-physical
* Non-inventory

Non-inventory, service, financial, and gift-card lines excluded from inventory value reports.

---

## Procurement path (derived dimension)

**Not persisted in Phase 9a.** Resolved by `Reports::ProcurementPathResolver`.

| Value | Typical condition |
| ----- | ----------------- |
| `vendor_order` | Variant/product vendor sourcing or `orderable` |
| `buyback` | Created from buyback session |
| `buyback_donation` | Buyback line donated / zero offer |
| `donation` | Manual donation intake (future explicit signal) |
| `manual_stock` | Inventory item without vendor source, not buyback |
| `not_applicable` | Service, financial, non-inventory, gift card |

---

## POS/register readiness checklist

Confirmed data sources for Phase 9b:

* Tenders: `pos_tenders.tender_type`
* Cash movements: register session + `pos_cash_movements`
* Tax snapshots: line `normal_tax_cents`, `applied_tax_source`, exemption/override records
* Discounts: `pos_discount_applications`, allocations
* COGS (operational margin): `Pos::LineCogsCalculator` snapshots — not GL COGS
