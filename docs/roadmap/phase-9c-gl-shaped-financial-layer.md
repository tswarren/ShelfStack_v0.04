# Phase 9c — GL-Shaped Financial Posting Layer

Part of [Phase 9 — Reporting and Accounting](phase-9-reporting-and-accounting.md).

## Purpose

Phase 9c introduces a GL-shaped financial posting layer for ShelfStack.

The goal is **not** to turn ShelfStack into full accounting software. Instead, ShelfStack should generate balanced, audit-friendly, export-ready financial postings from operational events such as POS transactions, gift card activity, buybacks, inventory receipts, inventory adjustments, cash drawer movements, and returns.

ShelfStack remains the operational system of record. External accounting software may remain the official general ledger. This phase creates the accounting-grade bridge between the two.

## Recommended Accounting Posture

ShelfStack should use this posture:

```text
ShelfStack is not the official GL in this phase.
ShelfStack generates balanced financial postings from operational records.
ShelfStack can produce internal financial reports and export-ready journal summaries.
The model remains compatible with a lightweight GL layer in the future.
```

This gives ShelfStack accurate financial reporting without requiring a full chart-of-accounts, trial balance, period-close, bank reconciliation, or financial-statement system in the first version.

---

# Problem Statement

ShelfStack already tracks many operational events that have financial meaning:

* Merchandise sales
* Returns and refunds
* Sales tax
* Discounts
* Gift card sales
* Gift card redemptions
* Store credit/trade credit issuance
* Store credit redemption
* Buyback cash payouts
* Buyback trade credit payouts
* Inventory receipts
* Inventory adjustments
* Returns to vendor
* Cash paid in
* Cash paid out
* Cash drops
* Register over/short

These events are currently meaningful operationally, but financial reporting requires a more explicit accounting representation.

Without a financial posting layer, reports risk being built from raw operational tables with inconsistent rules about:

* What counts as sales
* What is liability activity
* What affects inventory value
* What affects cash
* What is a refund versus a reversal
* What is a discount versus reduced revenue
* What belongs in tax payable
* What should be exported to external accounting software

Phase 9c creates a controlled financial layer that translates operational activity into balanced financial entries.

---

# Relationship to Phase 9b

Phase 9b can ship operational reports before Phase 9c is complete. Phase 9c introduces accounting-grade postings, reconciliation, and GL export readiness. It does **not** require rewriting all Phase 9b reports.

Phase 9b reports may initially use operational tables, snapshots, and ledgers defined in [Phase 9a reporting semantics](phase-9a-ux-foundation-for-reporting.md). After 9c, selected 9b reports may gain financial tie-out sections or alternate financial sources.

| Report | Phase 9b source | After Phase 9c |
| ------ | --------------- | -------------- |
| Customer request queue | Operational tables | Unchanged |
| Register summary | POS/session data | Add financial tie-out |
| Sales summary | POS snapshots | Optional financial-entry source |
| Tax collected | POS tax snapshots | Tie to tax payable entries |
| Discount summary | POS discount applications | Optional contra-revenue tie-out |
| Stored value liability | Stored value ledger | Tie to liability postings |
| Operational margin | COGS snapshots | Remains operational; not GL COGS |
| GL export | Not in 9b | **Phase 9c deliverable** |

Hybrid reports (e.g. register summary) combine operational context from 9b with financial totals from 9c.

---

# Goals

Phase 9c should:

1. Define a GL-shaped posting model.
2. Generate balanced debit/credit entries from operational events.
3. Preserve traceability from every financial posting back to the source record.
4. Support reversals without mutating historical entries.
5. Support configurable accounting mappings.
6. Produce export-ready financial summaries for external GL systems.
7. Support internal financial reports based on accounting-grade data.
8. Distinguish operational reporting from financial reporting.
9. Keep the door open for a future lightweight GL without building one prematurely.

---

# Non-Goals

Phase 9c does not include:

* Full general ledger replacement
* Trial balance
* Balance sheet
* Income statement
* Retained earnings handling
* Bank reconciliation
* Accounts payable aging
* Accounts receivable aging
* Full chart-of-accounts administration UI
* Accounting period close/reopen workflow
* Manual journal entry workflow
* Payroll accounting
* Multi-currency accounting
* Bank feed import
* Direct QuickBooks/Xero/Sage API integration
* Automated tax filing
* Full accountant portal
* Full GL audit package

Export-ready financials are in scope. Becoming the official accounting system is out of scope.

---

# Core Concept

Phase 9c introduces three levels of financial representation:

```text
Operational source record
  POS transaction, buyback, receipt, adjustment, cash movement, etc.

Financial event
  The accounting-significant event derived from the operational source.

Financial entry and lines
  Balanced debit/credit posting generated from the financial event.
```

Example:

```text
POS transaction #10482 completed
  → financial event: pos_sale_completed
  → financial entry:
      Debit  Cash/Card Clearing
      Credit Merchandise Sales
      Credit Sales Tax Payable
```

---

# Core Data Model

## 1. `financial_events`

Represents an operational event with accounting impact.

### Suggested Fields

```text
id
event_type
source_type
source_id
idempotency_key
store_id
register_session_id
business_date
occurred_at
posted_at
status
currency
reversal_of_id
created_by_id
metadata
timestamps
```

### Notes

* `idempotency_key` prevents duplicate financial events for the same source action. Use a stable key such as `pos_sale_completed:PosTransaction:10482` or enforce uniqueness on `(event_type, source_type, source_id)`.
* `source_type` and `source_id` link the event to the operational record.
* `business_date` supports register/session reporting.
* `occurred_at` records when the operational event happened.
* `posted_at` records when the financial posting was generated.
* `reversal_of_id` links reversal events to the original event.
* `metadata` stores source snapshots, rule versions, or export context where appropriate.

### Event Status Values

```text
pending
posted
reversed
error
no_posting_required
```

* `no_posting_required` — operational event recorded for audit visibility but no balanced entry expected (e.g. zero-value donation line, fully informational event).

### Example Event Types

```text
pos_sale_completed
pos_return_completed
pos_transaction_voided
gift_card_issued
gift_card_redeemed
store_credit_issued
store_credit_redeemed
buyback_completed
cash_paid_in
cash_paid_out
cash_drop
register_over_short
inventory_receipt_posted
inventory_adjustment_posted
return_to_vendor_posted
inventory_sale_cogs_posted
```

---

## 2. `financial_entries`

Represents one balanced financial posting generated from a financial event.

### Suggested Fields

```text
id
financial_event_id
entry_type
description
business_date
posted_at
posting_status
currency
total_debits_cents
total_credits_cents
is_balanced
posting_rule_version
timestamps
```

### Notes

* A financial event may produce one or more entries, though most events should produce one.
* `is_balanced` should be true before an entry can be posted or exported.
* `posting_rule_version` helps audit changes if posting rules evolve.
* Export state is **not** part of posting lifecycle. Posted entries remain posted after export.

### Posting Status Values

```text
draft
posted
reversed
error
```

Recommended first-pass rule:

```text
Only posted entries are used in financial reports and exports.
Draft/error entries are visible for review but excluded from official financial totals.
An entry with posting_status = posted remains posted even after export.
```

### Export State

Export membership is tracked separately from posting status:

```text
Derived from financial_export_entries join records, or
Optional cached export_status on financial_entries:
  unexported
  exported
  reexported
```

Financial report queries should filter on `posting_status = posted`, not on export state. Export batches determine which posted entries have been included in a given export file.

---

## 3. `financial_entry_lines`

Represents debit/credit lines within a financial entry.

### Suggested Fields

```text
id
financial_entry_id
accounting_account_id
account_code_snapshot
account_name_snapshot
account_type_snapshot
normal_balance_snapshot
external_account_ref_snapshot
side
amount_cents
store_id
department_id
sub_department_id
tax_category_id
store_tax_rate_id
tax_rate_label_snapshot
tax_rate_bps_snapshot
tender_type
procurement_path
vendor_id
customer_id
register_session_id
product_id
product_variant_id
source_type
source_id
memo
metadata
timestamps
```

### `side` Values

```text
debit
credit
```

### Notes

* Snapshot account fields protect historical entries if account names/codes change later.
* `external_account_ref_snapshot` preserves the external GL mapping reference at posting time.
* Tax lines may snapshot `store_tax_rate_id`, label, and `tax_rate_bps` from the effective store tax rate at transaction business date (via `TaxRateLookup` context). Tax category alone is not always sufficient when rates change.
* Dimensional fields allow financial reports by store, department, subdepartment, vendor, tender type, procurement path, etc.
* Not every line needs every dimension.
* `procurement_path` is a derived reporting dimension (see Phase 9a); it may be resolved at posting time.

---

## 4. `accounting_accounts`

Represents accounts used by posting rules and exports.

This is not yet a full chart of accounts module, but it provides enough structure for mappings and financial postings.

### Suggested Fields

```text
id
code
name
account_type
normal_balance
external_account_ref
is_active
system_key
timestamps
```

### Account Types

```text
asset
liability
revenue
contra_revenue
expense
cost_of_goods_sold
equity
clearing
```

### Examples

```text
1010 Cash in Drawer
1020 Card Clearing
1030 Check Clearing
1200 Inventory
1210 Used Inventory
1300 Receiving Accrual / AP Clearing
2200 Sales Tax Payable
2300 Gift Card Liability
2310 Store Credit Liability
4000 Merchandise Sales
4010 Cafe Sales
4020 Service/Fee Revenue
4090 Sales Discounts
5000 Cost of Goods Sold
6100 Inventory Adjustment Expense
6200 Cash Over/Short
```

---

## 5. `accounting_mappings`

Maps ShelfStack operational concepts to accounting accounts.

### Historical Note

A prior `accounting_mappings` table existed briefly in Phase 3 rework but was **removed in 2025-06** because it was never wired into runtime. GL resolution currently falls back to `departments.gl_account_code`. Phase 9c mappings supersede that table with a resolver-driven model. See [classification-cleanup.md](../implementation/classification-cleanup.md).

### Suggested Fields

```text
id
mapping_type
store_id
department_id
sub_department_id
tax_category_id
tender_type
procurement_path
inventory_behavior
payment_type
financial_event_type
accounting_account_id
priority
starts_on
ends_on
is_active
timestamps
```

### Mapping Types

```text
sales_revenue
sales_discount
sales_tax_payable
cash_tender
card_tender
check_tender
gift_card_liability
store_credit_liability
inventory_asset
used_inventory_asset
receiving_accrual
cost_of_goods_sold
inventory_adjustment_gain
inventory_adjustment_loss
cash_over_short
buyback_cash_payout
buyback_trade_credit_payout
```

### Priority

Mappings should support fallback priority:

```text
specific accounting mapping (most specific scope wins)
  → sub_department mapping
    → department mapping
      → departments.gl_account_code fallback (transitional)
        → system default account
```

`departments.gl_account_code` remains a transitional fallback until seeded `accounting_accounts` and mappings are in place. Seeded accounts may be created from existing department GL codes where appropriate.

Example scope specificity:

```text
sub_department + mapping_type
  overrides department + mapping_type
    overrides store-wide default
      overrides system default
```

---

## 6. `financial_exports`

Tracks export batches for external accounting systems.

### Suggested Fields

```text
id
export_type
external_system
date_range_start
date_range_end
store_id
status
entry_count
total_debits_cents
total_credits_cents
file_name
exported_at
exported_by_id
metadata
timestamps
```

### Export Statuses

```text
draft
generated
downloaded
sent
voided
error
```

### Notes

* Export records should link to included entries, likely through a join table such as `financial_export_entries`.
* Exporting should not mutate the financial entry amounts or change `posting_status`.
* Export membership is recorded via `financial_export_entries`; optional cached `export_status` on entries is derived from batch membership.

---

## 7. `financial_export_entries`

Join table linking export batches to financial entries.

### Suggested Fields

```text
id
financial_export_id
financial_entry_id
timestamps
```

---

# Posting Sources

Phase 9c should define financial events for the following operational sources.

## POS Transactions

Posting triggers:

```text
transaction completed
return completed
transaction voided/reversed
```

Financial effects may include:

* Sales revenue
* Discounts
* Sales tax payable
* Tender clearing/cash
* Gift card/store credit redemption
* Refund payable or cash/card refund
* COGS, if enabled

## Register Cash Movements

Posting triggers:

```text
cash paid in
cash paid out
cash drop
register close over/short
```

Financial effects may include:

* Cash in drawer
* Cash clearing
* Expense or adjustment account
* Over/short account

## Gift Cards and Stored Value

Posting triggers:

```text
gift card issued/sold
gift card redeemed
store credit issued
store credit redeemed
stored value adjusted
```

Financial effects:

* Gift card liability
* Store credit liability
* Cash/card clearing
* Sales revenue only when merchandise is sold, not when gift card is issued

## Buybacks

Posting triggers:

```text
buyback completed
buyback reversed/voided if supported
```

Financial effects:

* Used inventory asset
* Cash in drawer reduction
* Store credit liability increase
* Buyback expense if inventory value is not recognized directly

Recommended first-pass treatment:

```text
Accepted buyback inventory creates used inventory value.
Cash payout credits cash.
Trade credit payout credits store credit liability.
Rejected lines do not post.
Zero-value donated lines do not inflate used inventory value.
Mixed-payout sessions post only accepted value by payout type.
Voided completed buybacks create reversing entries aligned with buyback_void inventory reversal.
```

## Inventory Receipts

Posting triggers:

```text
receipt posted
receipt reversed/corrected
```

Financial effects:

* Inventory asset
* Receiving accrual / AP clearing

Recommended first-pass treatment if vendor invoices are not modeled:

```text
Debit   Inventory
Credit  Receiving Accrual / AP Clearing
```

## Inventory Adjustments

Posting triggers:

```text
manual adjustment posted
shrinkage posted
found inventory posted
damage/writeoff posted
```

Financial effects:

* Inventory asset
* Inventory adjustment gain/loss or shrinkage expense

## Returns to Vendor

Posting triggers:

```text
RTV posted
RTV accepted/credited if modeled later
```

Financial effects:

* Inventory asset reduction
* AP clearing / vendor credit receivable

---

# Posting Rule Examples

## 1. Cash Sale

```text
Debit   Cash in Drawer              $21.20
Credit  Merchandise Sales           $20.00
Credit  Sales Tax Payable            $1.20
```

## 2. Card Sale

```text
Debit   Card Clearing               $21.20
Credit  Merchandise Sales           $20.00
Credit  Sales Tax Payable            $1.20
```

## 3. Gift Card Sale

```text
Debit   Cash/Card Clearing          $25.00
Credit  Gift Card Liability         $25.00
```

Gift card sale is liability activity, not merchandise revenue.

## 4. Gift Card Redemption on Merchandise Sale

```text
Debit   Gift Card Liability         $21.20
Credit  Merchandise Sales           $20.00
Credit  Sales Tax Payable            $1.20
```

## 5. Mixed Tender Sale

```text
Debit   Cash in Drawer              $10.00
Debit   Card Clearing               $11.20
Credit  Merchandise Sales           $20.00
Credit  Sales Tax Payable            $1.20
```

## 6. Line or Transaction Discount

Option A — Net sales only:

```text
Debit   Cash/Card Clearing          $19.08
Credit  Merchandise Sales           $18.00
Credit  Sales Tax Payable            $1.08
```

Option B — Contra-revenue:

```text
Debit   Cash/Card Clearing          $19.08
Debit   Sales Discounts              $2.00
Credit  Merchandise Sales           $20.00
Credit  Sales Tax Payable            $1.08
```

Recommended:

```text
Support contra-revenue mapping if configured.
Otherwise report discounts operationally and post net sales.
```

## 7. Buyback Paid in Cash

```text
Debit   Used Inventory              $12.00
Credit  Cash in Drawer              $12.00
```

## 8. Buyback Paid in Trade Credit

```text
Debit   Used Inventory              $12.00
Credit  Store Credit Liability      $12.00
```

## 9. Inventory Receipt

```text
Debit   Inventory                   $90.00
Credit  Receiving Accrual           $90.00
```

## 10. Inventory Shrinkage Adjustment

```text
Debit   Inventory Adjustment Expense $8.00
Credit  Inventory                    $8.00
```

## 11. Cash Drop

```text
Debit   Cash Clearing / Safe        $200.00
Credit  Cash in Drawer              $200.00
```

## 12. Register Over/Short

If drawer is short:

```text
Debit   Cash Over/Short              $5.00
Credit  Cash in Drawer               $5.00
```

If drawer is over:

```text
Debit   Cash in Drawer               $5.00
Credit  Cash Over/Short              $5.00
```

---

# Posting Services

Introduce services that generate and validate financial postings.

## Suggested Service Objects

```text
FinancialPosting::EventBuilder
FinancialPosting::EntryBuilder
FinancialPosting::LineBuilder
FinancialPosting::MappingResolver
FinancialPosting::Validator
FinancialPosting::Poster
FinancialPosting::Reverser
FinancialPosting::Exporter
```

## Source-Specific Posting Services

```text
FinancialPosting::POS::SalePoster
FinancialPosting::POS::ReturnPoster
FinancialPosting::POS::CashMovementPoster
FinancialPosting::StoredValue::IssuePoster
FinancialPosting::StoredValue::RedemptionPoster
FinancialPosting::Buybacks::CompletionPoster
FinancialPosting::Inventory::ReceiptPoster
FinancialPosting::Inventory::AdjustmentPoster
FinancialPosting::Purchasing::ReturnToVendorPoster
```

## Validation Rules

Every financial entry must satisfy:

```text
total debits == total credits
all lines have valid accounts
amounts are positive integers in cents
side is debit or credit
source record is present
business date is present
currency is present
posting rule version is present
```

Entries that fail validation should not be marked posted or exported.

---

# Posting Integration

## Idempotency

Financial posting must be idempotent. A source event should not create duplicate financial events.

Requirements:

```text
Posting services use stable idempotency keys.
Unique constraint on idempotency_key, or on (event_type, source_type, source_id).
Retry of the same source action returns the existing financial event.
```

Follow the same pattern as `Inventory::Post` idempotency keys.

## Hook Points

Financial posting should be triggered from operational completion paths:

```text
POS transaction completed
POS return/refund completed
POS transaction voided
Buyback session completed
Buyback session voided
Stored value ledger entry posted
Register cash movement posted (paid in, paid out, drop)
Register session closed (over/short)
Inventory receipt posted
Inventory adjustment posted
Return to vendor posted
```

Posting should run **after** operational records are finalized. Operational completion should succeed even if financial posting fails, unless explicitly configured otherwise. Failures must be visible and retryable.

### Transaction Flow

```text
Operational transaction completes (POS, buyback, receipt, etc.).
Financial event is created or enqueued (idempotent).
Posting service attempts to build and post entries.
If posting succeeds, financial entry posting_status = posted.
If posting fails, source record remains completed; financial event/entry posting_status = error.
Error appears in financial posting review queue.
Authorized user can retry after fixing mapping or data issue.
```

Operational events with no accounting amount should not create zero-dollar entry lines. The financial event may be marked `no_posting_required` when audit visibility is needed without a balanced entry.

## Zero-Amount Posting Rule

```text
Financial entry lines must not post zero-dollar amounts.
Operational events with no accounting impact may create no financial entry.
Alternatively, create a financial event with status no_posting_required for audit visibility.
Examples: zero-value buyback donations, no-charge informational events, fully offset internal movements.
```

## Failure, Retry, and Backfill

```text
Posting errors create financial events or entries in error posting_status.
Admins can review failed postings and retry via FinancialPosting::Poster or equivalent.
Audit events should record posting, reversal, retry, and export actions.
```

See **Open Decisions — Backfill Strategy** for backfill policy. Default: forward-only from go-live date.

## POS Snapshot Dependency

POS financial postings must use finalized POS transaction, line, tax, discount, tender, and stored-value **snapshots**.

Posting services should **not** re-run pricing, tax, or discount logic except for validation/cross-checking against `Pos::TaxRecalculator`, `Pos::DiscountRecalculator`, and receipt totals.

Gift card sale lines are liability activity, not merchandise revenue. Structured discount applications (Phase 8.5-1) and tax exception snapshots (Phase 8.5-2) must be respected.

## COGS Boundary

```text
Operational margin (Pos::OperationalMarginReport) remains operational reporting in Phase 9.
COGS journal posting (inventory_sale_cogs_posted) is optional/deferred until moving cost is sufficiently reliable.
If COGS posting is enabled, it must use sale-time cost snapshots from Pos::LineCogsCalculator, not live recalculated MAC.
```

---

# Reversals and Corrections

Historical financial entries should not be edited after posting.

Use reversal entries instead.

## Rules

```text
Posted entries are immutable except for export metadata.
Corrections create new entries.
Voids/refunds/reversals create reversing financial events.
Reversal entries link to the original event or entry.
Financial reports can include or exclude reversals depending on report purpose.
```

## Example

Original sale:

```text
Debit   Cash                         $21.20
Credit  Merchandise Sales            $20.00
Credit  Sales Tax Payable             $1.20
```

Reversal:

```text
Debit   Merchandise Sales            $20.00
Debit   Sales Tax Payable             $1.20
Credit  Cash                         $21.20
```

---

# Reporting Integration

Phase 9c supports financial reporting by providing accounting-grade sources for Phase 9b and later reports.

## Reports That Should Use Financial Postings

```text
Sales summary
Tax collected
Stored value liability/activity
Cash drawer activity
Register summary financial section
Discount financial summary
Buyback financial summary
Inventory adjustment financial summary
External GL export summary
```

## Reports That May Remain Operational

```text
Customer request queue
Open PO status
Receiving discrepancy queue
Inventory on-hand detail
Item activity history
Buyback operational line detail
```

## Hybrid Reports

Some reports should combine operational data and financial postings.

Example:

```text
Register summary
  Operational: transaction count, line count, session times, cashier
  Financial: tender totals, sales, tax, stored value, cash movements
```

---

# Export-Ready Financials

Phase 9c should support export batches even if direct accounting software integration is deferred.

## Initial Export Types

```text
journal_summary_csv
journal_detail_csv
external_gl_transfer_file
```

## Export Should Include

* Export batch ID
* Date range
* Store
* Account code
* Account name
* Debit amount
* Credit amount
* Memo
* Source summary
* Department/subdepartment where applicable
* Tax category where applicable
* Tender type where applicable
* External account reference if configured

## Export Rules

```text
Only posted, balanced entries can be exported.
Export batches are append-only.
Default export includes only posted, balanced, unexported entries.
Re-export requires explicit permission and creates a new export batch marked as re-export.
Voiding an export batch does not delete entries; it only invalidates that batch record.
Export does not change operational records.
```

Optional soft-close (not full period close):

```text
An export cutoff date may prevent casual re-export of entries on or before exported dates.
Full accounting period close/reopen remains deferred.
```

---

# User Interface Scope

Phase 9c should include a minimal admin/reporting UI.

## Placement

| Area | Location |
| ---- | -------- |
| Accounting accounts | Setup / Accounting |
| Accounting mappings | Setup / Accounting |
| Financial events | Reports or Manager Desk / Accounting |
| Financial entries | Reports or Manager Desk / Accounting |
| Export batches | Reports or Manager Desk / Accounting |
| Posting error review | Reports or Manager Desk / Accounting |

Financial admin screens should use the Phase 9a report view contract for list/filter/detail layouts where applicable.

## Permissions

Suggested permission keys:

```text
accounting.accounts.view
accounting.mappings.manage
financial_events.view
financial_entries.view
financial_exports.generate
financial_exports.download
financial_postings.retry
financial_exports.reexport
```

Store-scoped authorization should apply where financial data is store-specific.

## In Scope

```text
Accounting account list
Accounting mapping list
Financial event list
Financial entry detail
Financial entry line detail
Posting preview for selected records where useful
Posting error review
Financial export batch list
Export detail/download screen
```

## Not in Scope

```text
Full chart-of-accounts editor with hierarchy
Manual journal entry screen
Period close UI
Bank reconciliation UI
Financial statement builder
Accountant portal
```

## Suggested Screens

### Financial Events Index

Purpose:

Show generated financial events and posting status.

Columns:

```text
Date
Event type
Source
Store
Status
Entry count
Debits
Credits
Export status
Actions
```

### Financial Entry Detail

Purpose:

Show a balanced entry and its source record.

Sections:

```text
Entry header
Source record link
Debit/credit lines
Dimensions
Validation status
Export status
Reversal link if applicable
```

### Accounting Mappings

Purpose:

Allow admin review of default mappings.

Columns:

```text
Mapping type
Operational scope
Account
Priority
Active?
Effective dates
```

Initial mappings can be seed-driven if editable UI is deferred.

### Export Batches

Purpose:

Generate and download export-ready journal summaries.

Filters:

```text
Date range
Store
Entry type
Export status
```

---

# Suggested Implementation Order

## Step 1 — Design and Seeds

```text
Define account types and normal balances.
Seed default accounting_accounts (optionally from departments.gl_account_code).
Seed default accounting_mappings.
Document posting rules and mapping priority chain.
```

## Step 2 — Core Tables

```text
financial_events
financial_entries
financial_entry_lines
accounting_accounts
accounting_mappings
financial_exports
financial_export_entries
```

## Step 3 — Posting Engine

```text
Mapping resolver (including gl_account_code fallback)
Entry builder
Line builder
Validator
Poster (idempotent)
Reverser
Retry/repair path for error status
```

## Step 4 — POS and Stored Value Posting

Implement first:

```text
POS sale completed
POS return/refund completed
Gift card issued
Gift card redeemed
Store credit issued
Store credit redeemed
Cash paid in/out/drop
Register over/short
```

Reason:

These are most important for register summary, sales, tax, tender, and stored value reports.

## Step 5 — Buyback Posting

Implement:

```text
Buyback completed with cash payout
Buyback completed with trade credit payout
Buyback reversal if supported
```

## Step 6 — Inventory and Purchasing Posting

Implement:

```text
Inventory receipt posted
Inventory adjustment posted
Return to vendor posted
COGS posting if cost model is ready
```

COGS may be deferred if moving cost is not reliable enough.

## Step 7 — UI and Reporting Integration

```text
Financial entries index/detail
Posting error review
Accounting mapping review
Export batch generation
Financial report source integration
```

## Step 8 — Export

```text
CSV journal summary
CSV journal detail
Export batch tracking
Re-export controls
```

---

# Acceptance Criteria

Phase 9c is complete when:

## Core Posting

```text
- Financial events can be generated from supported operational records.
- Financial posting is idempotent; duplicate source events do not create duplicate entries.
- Financial entries contain balanced debit/credit lines with no zero-dollar amounts.
- Zero-impact operational events may use financial event status no_posting_required.
- Financial entries are traceable back to source records.
- posting_status = posted entries are immutable; export state is tracked separately.
- Reversals are represented as reversing entries, not edits.
- Posting failures are visible for review and retry.
- Operational completion is not silently blocked by posting failure unless explicitly configured.
```

## Account Mapping

```text
- Default accounting accounts are seeded.
- Default mappings are seeded.
- Mappings can resolve accounts for sales, tax, tender, stored value, buybacks, inventory, and cash movements.
- Account snapshots are stored on financial entry lines.
```

## POS / Stored Value

```text
- Completed POS sale generates balanced financial entries.
- POS return/refund generates balanced reversal or refund entries.
- Gift card sale posts to liability, not merchandise revenue.
- Gift card redemption reduces liability.
- Store credit issuance creates liability.
- Store credit redemption reduces liability.
- Cash paid in/out/drop creates appropriate cash movement entries.
```

## Buybacks

```text
- Completed cash buyback posts used inventory and cash reduction.
- Completed trade credit buyback posts used inventory and store credit liability.
- Rejected buyback lines do not post.
- Zero-value donated lines do not inflate used inventory value.
- Voided completed buybacks create reversing entries.
```

## Inventory / Purchasing

```text
- Posted inventory receipt can generate inventory/accrual entry.
- Posted inventory adjustment can generate inventory gain/loss entry.
- Return to vendor posting can generate inventory reduction and clearing/credit entry where supported.
- Non-inventory, service, and stored-value items are excluded from inventory asset postings.
```

## Export

```text
- Posted balanced entries can be included in export batches.
- Export batches are append-only and auditable.
- Default export excludes already-exported entries.
- Re-export requires explicit permission and a new batch.
- Journal summary CSV can be generated.
- Journal detail CSV can be generated.
- Exported entries are traceable.
```

## Reporting

```text
- Financial reports can use financial entries as their accounting-grade source.
- Register summary can reconcile tender, sales, tax, stored value, and cash movement activity.
- Sales tax report can be supported from postings.
- Stored value liability/activity report can be supported from postings.
```

---

# Testing Requirements

## Unit Tests

Test:

```text
Mapping resolution
Entry balancing
Posting validation
Reversal generation
Export batch inclusion
Account snapshot behavior
```

## Service Tests

Test posting services for:

```text
cash sale
card sale
mixed tender sale
gift card sale
gift card redemption
store credit issuance
store credit redemption
cash buyback
trade credit buyback
cash paid in/out/drop
inventory receipt
inventory adjustment
return/refund
```

## Integration Tests

Test:

```text
completed POS transaction creates financial event and entry
void/refund creates reversing or refund entry
completed buyback creates financial posting
posted receipt creates financial posting
export batch includes correct entries
```

## Report Tests

Test that reports:

```text
include entries with posting_status = posted
exclude draft/error entries
respect date range
respect store/register filters
handle refunds/reversals correctly
handle stored value liability correctly
do not conflate export state with posting status
```

---

# Open Decisions

## 1. Discount Posting Method

Choose one:

```text
A. Post net sales only and report discounts operationally.
B. Post gross sales with discounts as contra-revenue.
C. Support both through accounting mappings.
```

Recommended:

```text
Support net sales first, but design mappings to allow contra-revenue.
```

## 2. COGS Timing

Choose one:

```text
A. Post COGS at sale completion.
B. Report COGS operationally from inventory cost but do not post yet.
C. Defer COGS until moving cost is proven reliable.
```

Recommended:

```text
Defer COGS posting or make it optional until moving cost is reliable.
```

## 3. Receiving/AP Treatment

Choose one:

```text
A. Post inventory receipt against AP clearing/accrual.
B. Do not post receiving until vendor invoices are modeled.
C. Post receipt entries only for internal inventory valuation.
```

Recommended:

```text
Post to Receiving Accrual / AP Clearing if inventory value reporting depends on it; otherwise keep as optional.
```

## 4. Official GL Status

Recommended decision:

```text
ShelfStack is not the official GL in Phase 9c.
External accounting software remains the official accounting system.
ShelfStack produces accounting-grade postings and export-ready summaries.
```

## 5. Export Granularity

Choose one:

```text
A. Daily summarized journal by account.
B. Register-session summarized journal.
C. Transaction-level detail.
D. Support multiple export levels.
```

Recommended:

```text
Support journal summary first, with detail export available for audit.
```

## 6. Backfill Strategy

Choose one:

```text
A. Forward-only from Phase 9c go-live date.
B. Backfill completed operational records from a selected historical date.
C. Backfill only selected domains (e.g. POS and stored value).
```

Recommended:

```text
Forward-only first, with optional backfill as a separate controlled effort.
```

Backfill can be expensive and risky. Treat it as a deliberate follow-on project, not a default Phase 9c requirement.

---

# Risks

## Scope Creep into Full Accounting

A GL-shaped posting layer can easily become a full GL. Keep Phase 9c focused on generated postings, mappings, reversals, reports, and exports.

## Incorrect Posting Rules

Incorrect accounting mappings can create misleading reports. Default mappings must be reviewed carefully.

## Inventory Cost Uncertainty

Inventory and COGS postings depend on reliable cost data. If moving average cost is not stable, COGS posting should be deferred.

## Gift Card / Stored Value Misclassification

Gift card sales and trade credit issuance must be treated as liability activity, not ordinary sales revenue.

## Reversal Complexity

Voids, refunds, and corrections must be carefully modeled so reports can distinguish original activity from reversals.

## External Accounting Expectations

Different stores may use different chart-of-account structures. Mappings and export formats should be configurable enough to adapt.

---

# Future Expansion

Potential later phases:

```text
Full chart-of-accounts management
Manual journal entries
Accounting periods
Period close/reopen
Trial balance
Balance sheet
Income statement
Bank reconciliation
Accounts payable integration
Direct QuickBooks/Xero/Sage integration
Multi-store consolidated reporting
Multi-currency accounting
Advanced audit exports
```

---

# Summary

Phase 9c creates the accounting-grade bridge between ShelfStack operations and financial reporting.

The core principle:

```text
Operational events generate balanced financial postings.
Financial postings support reports and exports.
External accounting software remains the official GL.
ShelfStack stays GL-shaped, not full-GL, in this phase.
```

This gives ShelfStack accurate financial data for reporting while avoiding the scope and risk of building a complete accounting system too early.

## Related Documents

```text
docs/roadmap/phase-9-reporting-and-accounting.md
docs/roadmap/phase-9a-ux-foundation-for-reporting.md
docs/roadmap/phase-9b-reports.md
docs/implementation/classification-cleanup.md
```
