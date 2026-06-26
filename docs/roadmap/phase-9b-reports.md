# Phase 9b — Operational Reports

Part of [Phase 9 — Reporting and Accounting](phase-9-reporting-and-accounting.md).

## Purpose

Phase 9b implements ShelfStack’s operational reporting layer using the standards and semantics established in Phase 9a.

Reports should help store staff and managers answer operational questions about sales, taxes, discounts, cash drawer activity, buybacks, inventory value, purchasing/receiving, stored value, margin, and customer request queues.

The first reporting phase should prioritize correctness, reconciliation, filtering, printability, and consistency over advanced analytics.

Phase 9b does **not** implement GL-shaped financial postings or accounting export. Those belong to [Phase 9c](phase-9c-gl-shaped-financial-layer.md). After 9c, selected 9b reports may gain financial tie-out sections.

## Reports vs Dashboards

Phase 9b reports may use metric strips and summaries, but they should **not** become interactive dashboards. Dashboards, saved views, charts, and trend analytics remain deferred unless separately scoped.

## Goals

Phase 9b should:

1. Consolidate and extend the initial set of core operational reports.
2. Use the shared report view contract from Phase 9a.
3. Apply consistent filters, metric cards, tables, and print layout.
4. Use documented reporting semantics for statuses, dates, money, taxes, discounts, tenders, inventory, buybacks, purchasing, and stored value.
5. Migrate existing report surfaces toward shared components where practical.
6. Provide useful management visibility without building a full analytics platform.
7. Establish a reusable architecture for future reports.

## Non-Goals

Phase 9b does not include:

* Advanced dashboards
* Charts unless trivially useful
* Custom report builder
* Saved report views
* Scheduled report delivery
* Automated email reports
* Data warehouse
* GL export or journal transfer files (Phase 9c)
* Accounting system integration (Phase 9c)
* Multi-store comparative analytics beyond basic store filters if available
* Predictive analytics
* Full BI-style drilldown
* Full POS command integration
* Report-specific framework migration

## Current Report Surfaces to Consolidate

Phase 9b is not greenfield work. Reports and report-like surfaces already exist:

| Surface | Current location | Notes |
| ------- | ---------------- | ----- |
| Register summary | `/pos/reports/register_summary` | Print layout, breakdowns |
| Sales & revenue summary | `/pos/reports/summary` | CSV export |
| Sales list | `/pos/reports/sales` | CSV export |
| Returns list | `/pos/reports/returns` | CSV export |
| Drawer / cash | `/pos/reports/drawer` | Session summary |
| Operational margin | `/pos/reports/operational_margin` | Phase 8-5; non-GL |
| Buyback summary | `/buybacks/reports` | Ad hoc layout |
| Stored value liability | Customers stored value reports | Phase 7B |
| Inventory value rollups | `/inventory/balances`, enterprise index | Read surfaces |

### Migration Decisions

Phase 9b should decide and document:

* Which reports move into a unified **Reports** area under Manager Desk (per [ui-ux-concept.md](../specifications/ui-ux-concept.md))
* Which remain workspace-nested but adopt shared report partials and the 9a view contract
* Which routes keep aliases for backward compatibility (e.g. `/pos/reports/*`)
* How permissions compose (`pos.reports.*`, `buybacks.reports.view`, `stored_value.reports.view`, future `reports.*`)

Recommended approach:

```text
Unified Reports navigation as the primary entry point.
Workspace-nested routes may remain as aliases during transition.
All reports share layout, filters, metrics, tables, and print hooks from 9a.
```

## Reporting Dimensions

Use consistent dimensions across reports:

```text
store
department
subdepartment
tax category
tender type
product variant
vendor
register session
procurement path (derived; see Phase 9a)
inventory behavior / inventory tracking
```

Do not use legacy **merchandise class** terminology unless that entity is formally reintroduced.

## Initial Report Set

### 1. POS Register Summary

Purpose:

Summarize a register session for cashier/manager reconciliation.

Source of truth:

* `pos_register_sessions` for session boundaries, open/close times, and drawer counts
* Completed `pos_transactions` and line/tax/discount/tender snapshots for sales, tax, discount, and tender totals
* Register cash movement records for paid in, paid out, drops, and cash refunds
* Stored value ledger for gift card / store credit issue and redemption summaries where applicable
* After Phase 9c: `financial_entries` for optional financial tie-out

Should include:

* Store/register/workstation
* Session open/close time
* Cashier/opened by/closed by
* Beginning cash
* Sales totals
* Return/refund totals
* Tax collected
* Discounts
* Tender totals by type
* Cash paid in
* Cash paid out
* Cash drops
* Cash refunds
* Expected cash
* Counted cash
* Over/short
* Gift card/store credit issue/redemption summary where applicable
* Transaction count
* Voids/cancellations count if available
* Notes/exceptions

After Phase 9c: optional financial tie-out section comparing operational totals to posted financial entries.

Primary filters:

* Store
* Register/workstation
* Session
* Date range
* Cashier/user

Output:

* On-screen report
* Print-friendly layout

### 2. Sales Summary

Purpose:

Show sales by operational grouping.

Source of truth:

* Completed `pos_transactions` filtered by business date / completed_at
* `pos_transaction_lines` and cached line/transaction cents fields for amounts
* Line snapshots for department/subdepartment and tax category grouping
* After Phase 9c: optional `financial_entry_lines` for revenue tie-out

Should include:

* Gross sales
* Returns/refunds
* Discounts
* Net sales
* Tax
* Quantity sold
* Transaction count
* Average transaction value where useful

Groupings:

* Department
* Subdepartment
* Tax category
* Store
* Date/business date
* Optional product/variant drilldown later

Primary filters:

* Date range
* Store
* Department/subdepartment
* Transaction type

### 3. Tax Collected

Purpose:

Support tax review and reconciliation.

Source of truth:

* Completed `pos_transactions` and `pos_transaction_lines`
* Line tax snapshots: `tax_cents`, `normal_tax_cents`, `applied_tax_source`
* Phase 8.5-2a exemption records and 8.5-2b line override records where applicable
* `TaxRateLookup` context for rate labels at transaction business date (display only; totals from snapshots)
* After Phase 9c: tax payable `financial_entry_lines` for tie-out

Should include:

* Taxable sales by tax category/rate
* Non-taxable/exempt sales
* Tax collected by rate
* Tax refunds
* Net tax collected
* Exemption reason summary if available (Phase 8.5-2a)
* Line tax overrides (Phase 8.5-2b)

Primary filters:

* Date range
* Store
* Tax category
* Tax rate
* Exemption status

### 4. Discount Summary

Purpose:

Show markdowns, promotions, and approval-sensitive discount activity.

Source of truth:

* Completed `pos_transactions` and `pos_transaction_lines`
* Phase 8.5-1 `pos_discount_applications` and `pos_discount_allocations` (audit source)
* Cached `discount_cents`, `line_discount_cents`, `transaction_discount_cents` for cross-check
* After Phase 9c: optional contra-revenue `financial_entry_lines` if configured

Should include:

* Line discounts
* Transaction/order discounts
* Discount reasons (Phase 8.5-1 applications)
* Discount amount
* Discount percentage where meaningful
* Supervisor approvals
* Discounts by cashier/user
* Discounts by department/subdepartment

Primary filters:

* Date range
* Store
* Discount reason
* User/cashier
* Department/subdepartment

### 5. Cash Drawer Activity

Purpose:

Explain cash movement outside normal card/gift/store-credit tendering.

Source of truth:

* `pos_register_sessions` for session context and opening/closing cash
* Register cash movement records (paid in, paid out, drops)
* Cash tender rows on completed `pos_transactions` for cash sales and refunds
* Session summary services (e.g. `Pos::RegisterSessionSummary`) where already implemented
* After Phase 9c: cash-related `financial_entry_lines` for tie-out

Should include:

* Opening cash
* Cash sales
* Cash refunds
* Paid in
* Paid out
* Drops
* Expected cash
* Counted cash
* Over/short
* Movement reasons
* User/cashier
* Timestamp

Primary filters:

* Date range
* Store
* Register/workstation
* Session
* Cash movement type
* User/cashier

### 6. Buyback Summary

Purpose:

Summarize used buyback activity and inventory intake from buybacks.

Source of truth:

* `buyback_sessions` and `buyback_lines` for session status, payout mode, and line outcomes
* Completed/voided session totals for cash paid and trade credit issued
* `inventory_postings` / ledger with `source: BuybackSession` for posted inventory intake
* After Phase 9c: buyback `financial_entry_lines` for tie-out

Should include:

* Buyback sessions
* Accepted lines
* Rejected lines
* Cash paid
* Trade credit issued
* Inventory posted
* Items needing review
* Buyback by condition
* Buyback by department/subdepartment
* Seller/customer where authorized

Primary filters:

* Date range
* Store
* Status
* Payout type
* Condition
* Department/subdepartment
* Needs review

Consolidate existing `/buybacks/reports` into the shared report contract.

### 7. Inventory Value Snapshot

Purpose:

Show estimated inventory value at a point in time or current value.

Source of truth:

* `inventory_balances` for on-hand quantities and cached retail/cost values
* `inventory_ledger_entries` for movement history when needed
* `Inventory::Eligibility` / tracking resolver to exclude non-inventory items
* Product variant and subdepartment for grouping
* Not PO drafts or unposted receipts

Should include:

* On hand quantity
* Retail value
* Cost value
* Moving average cost where available
* Department/subdepartment
* Store
* Inventory behavior / tracking
* Exclusions for non-inventory/service/stored-value items
* Negative on-hand exceptions
* Items with missing/unknown cost

Primary filters:

* Store
* Department/subdepartment
* Inventory behavior
* As-of date if supported
* Include/exclude negative quantities
* Include/exclude zero on-hand

Initial version may be a current snapshot if historical as-of valuation is not yet reliable.

Consolidate existing inventory balance rollups where practical.

### 8. Purchasing and Receiving Summary

Purpose:

Summarize vendor ordering and receiving activity.

Source of truth:

* `purchase_orders` and `purchase_order_lines` for order status and open quantities
* `receipts` and `receipt_lines` for received, accepted, and rejected quantities
* Posted receiving inventory ledger entries for accepted quantity only
* Vendor and variant sourcing records for cost context

Should include:

* Purchase orders by status
* Open PO lines
* Quantity ordered
* Quantity received
* Quantity accepted
* Quantity rejected/damaged
* Open/backordered quantity
* Receipt totals
* Vendor
* Expected/list cost
* Received cost
* Discrepancies

Primary filters:

* Date range
* Store
* Vendor
* PO status
* Receipt status
* Department/subdepartment
* Discrepancy status

### 9. Customer Request Queue / Status Report

Purpose:

Show open demand and customer-facing follow-up work.

Source of truth:

* Customer request / special order / TBO workflow tables and status fields
* `CustomerRequests::HeaderStatusResolver` or equivalent for derived header status
* Linked variant, customer, and assignment fields
* Not financial postings

Should include:

* Open customer requests
* Ready for pickup
* Awaiting customer response
* Awaiting order/receiving
* Special orders
* TBO demand
* Completed requests
* Cancelled requests
* Aging
* Assigned user if available
* Linked variant/item
* Customer

Primary filters:

* Status
* Date range
* Store
* Request type
* Assigned user
* Ready/not ready
* Department/subdepartment

### 10. Operational Margin Report

Purpose:

Show operational gross margin from sale-time COGS snapshots (Phase 8-5). This is **operational reporting**, not GL COGS posting.

Source of truth:

* Completed `pos_transactions` (voided excluded)
* `Pos::LineCogsCalculator` / pre-sale COGS snapshots on lines
* `Pos::OperationalMarginReport` service logic
* Not live MAC recalculation; not Phase 9c COGS journal entries

Should include:

* Net sales
* Actual vs estimated COGS
* Margin dollars and percentage
* Breakdown by department/subdepartment where useful
* Voided transactions excluded

Consolidate existing `Pos::OperationalMarginReport` into the shared report contract.

Primary filters:

* Date range
* Store
* Register session where applicable
* Department/subdepartment

### 11. Stored Value Liability / Activity Report

Purpose:

Show stored value balances and ledger activity for gift cards, store credit, and trade credit.

Source of truth:

* `stored_value_accounts` for current liability balances
* `stored_value_ledger_entries` for activity in date range
* `StoredValue::LiabilityReport` service logic
* After Phase 9c: liability `financial_entry_lines` for optional tie-out

Should include:

* Liability balance by account type and store
* Activity by entry type for date range
* Issue, redeem, adjust, void summaries where applicable

Consolidate existing `StoredValue::LiabilityReport` into the shared report contract.

After Phase 9c: optional tie-out to liability account postings.

Primary filters:

* Date range
* Store
* Account type

## Shared Report Behavior

All reports should use the Phase 9a report view contract.

### Required Layout

```text
Report header
Filter bar
Metric strip
Report body
Empty state where applicable
Print/export actions
```

### Required Behavior

* Filters should be visible and understandable.
* Reports should show the active date range/scope.
* Metric totals should appear before detailed tables.
* Tables should use consistent numeric alignment.
* Empty reports should explain whether there is no data or the filters are too narrow.
* Report pages should be printable.
* Report totals should be explainable and reconcilable.
* Reports should avoid hidden business rules.
* Detail rows may link to `/items/item?...` per [phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md). Report links are read-only navigation; do not assume write actions from report links.

### Print and Export Behavior

Phase 9b includes **simple print and CSV exports** where already implemented or low-effort.

Priority print reports:

* POS register summary
* Tax collected
* Sales summary
* Inventory value snapshot

Automated exports, scheduled reports, bulk accounting exports, and GL transfer files belong to Phase 9c or later.

Print layouts should be clean, compact, and avoid interactive-only controls.

## Relationship to Phase 9c

| Report | Phase 9b source | After Phase 9c |
| ------ | --------------- | -------------- |
| Customer request queue | Operational tables | Unchanged |
| Register summary | POS/session data | Add financial tie-out |
| Sales summary | POS snapshots | Optional financial-entry source |
| Tax collected | POS tax snapshots | Tie to tax payable entries |
| Discount summary | POS discount applications | Optional contra-revenue tie-out |
| Stored value liability | Stored value ledger | Tie to liability postings |
| Operational margin | COGS snapshots | Remains operational; not GL COGS |
| GL export | Not in 9b | Phase 9c deliverable |

9c does not require rewriting all 9b reports. It adds financial entries, reconciliation, and export readiness.

## Suggested Technical Architecture

Use a consistent report architecture.

Recommended structure:

```text
app/controllers/reports/
app/services/reports/
app/presenters/reports/
app/views/reports/
app/views/reports/shared/
```

Existing workspace controllers (e.g. `Pos::ReportsController`) may remain during migration; new shared code should live under `Reports::` where practical.

Recommended object pattern:

```text
Reports::Parameters
Reports::Query / Reports::Builder
Reports::Result
Reports::Presenter
```

Each report should have:

* Parameter object or normalized params method
* Query/service object
* Result object or structured hash
* Presenter/helper methods for display
* Shared report partials for filters, metrics, tables, empty states

Avoid putting complex report math directly in views.

## Testing Requirements

Each report should have tests for:

* Inclusion/exclusion of draft/cancelled/voided records
* Date range boundaries
* Store/session/vendor/department/subdepartment filters where applicable
* Totals and subtotals
* Refund/negative amount behavior
* Tax/discount calculations where applicable
* Empty result state

At minimum:

```text
service/query tests for report totals
request/controller tests for report access and rendering
system tests for one representative report filter flow
```

## Suggested Implementation Order

### Step 0 — Current-State Audit

* Inventory existing report surfaces (see table above).
* Decide unified Reports nav vs workspace-nested aliases.
* Identify reports to migrate vs rewrite.

### Step 1 — Report Infrastructure

* Add Reports navigation.
* Add shared report layout/partials.
* Add shared filter/date range component.
* Add shared metric strip.
* Add shared report table conventions.
* Add print stylesheet hooks.

### Step 2 — POS/Register Reports

Build or migrate first because they validate core money, tender, tax, discount, and cash movement semantics.

* POS Register Summary (migrate existing)
* Cash Drawer Activity (migrate existing)
* Tax Collected
* Discount Summary

### Step 3 — Sales and Margin Reports

* Sales Summary by department/subdepartment
* Sales by tax category
* Operational Margin Report (standardize existing)

### Step 4 — Inventory, Purchasing, and Stored Value

* Inventory Value Snapshot (consolidate existing rollups)
* Purchasing/Receiving Summary
* Stored Value Liability / Activity (standardize existing)

### Step 5 — Customer/Buyback Operational Reports

* Buyback Summary (migrate existing)
* Customer Request Queue/Status

## Acceptance Criteria

Phase 9b is complete when:

* Reports navigation exists (unified entry point documented).
* Each initial report has a documented purpose and filters.
* Existing report surfaces are migrated or explicitly aliased with shared components.
* Reports use shared Phase 9a report UI components.
* Reports use standardized formatting for money, percentages, quantities, dates, and statuses.
* Reports respect documented inclusion/exclusion rules.
* POS register summary can be printed and used for reconciliation.
* Sales, tax, discount, and cash reports reconcile against POS transaction data.
* Inventory value report excludes non-inventory/service/stored-value items.
* Buyback report distinguishes cash paid from trade credit issued.
* Operational margin report uses sale-time COGS snapshots and excludes voided transactions.
* Stored value liability report shows balances and activity by account type.
* Customer request report shows actionable queue status.
* Report links follow the Phase 8.5-4 item drill-down contract.
* Report query/service logic is tested.
* Report views do not contain complex business math.
* No report introduces new one-off button, table, filter, or metric styles without adding them to the shared report/component standard.

## Deferred Reporting Features

Defer until after Phase 9b (or to Phase 9c where noted):

* Charts and graphs
* Saved report views
* Scheduled reports
* GL/accounting export and journal transfer files (**Phase 9c**)
* Report builder
* Multi-period trend dashboards
* Advanced drilldown
* Role-specific dashboards
* Email delivery
* Forecasting/predictive metrics
* Stock aging (future Phase 9 extension unless scoped into 9b)
* Vendor performance analytics beyond purchasing summary
* Audit/event reports beyond operational needs

## Risks

### Misleading Totals

Reports that include the wrong statuses or date fields can look correct while being wrong. Phase 9a semantics must be followed.

### Overbuilding

The first reporting phase should not become a BI platform. Start with operational reports that stores need to reconcile and manage daily work.

### Performance

Large reports may need query optimization, indexes, or summary tables later. Do not introduce a reporting warehouse prematurely.

### Print Complexity

Print layouts can become time-consuming. Prioritize print only for reports that stores are likely to file, reconcile, or hand to managers.

### Data Gaps

Some desired report fields may not be available yet. Reports should clearly mark unavailable metrics rather than infer unsupported totals.

### Migration Drift

Leaving old report layouts in place while building new ones can duplicate logic. Prefer migrating to shared partials early.

## Related Documents

```text
docs/roadmap/phase-9-reporting-and-accounting.md
docs/roadmap/phase-9a-ux-foundation-for-reporting.md
docs/roadmap/phase-9c-gl-shaped-financial-layer.md
docs/handoff/phase-9-item-drill-down-contract.md
```
