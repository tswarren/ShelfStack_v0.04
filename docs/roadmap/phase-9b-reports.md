# Phase 9b — Reports

## Purpose

Phase 9b implements ShelfStack’s initial operational reporting layer using the standards and semantics established in Phase 9a.

Reports should help store staff and managers answer operational questions about sales, taxes, discounts, cash drawer activity, buybacks, inventory value, purchasing/receiving, and customer request queues.

The first reporting phase should prioritize correctness, reconciliation, filtering, printability, and consistency over advanced analytics.

## Goals

Phase 9b should:

1. Build the initial set of core operational reports.
2. Use the shared report view contract from Phase 9a.
3. Apply consistent filters, metric cards, tables, and print layout.
4. Use documented reporting semantics for statuses, dates, money, taxes, discounts, tenders, inventory, buybacks, purchasing, and stored value.
5. Provide useful management visibility without building a full analytics platform.
6. Establish a reusable architecture for future reports.

## Non-Goals

Phase 9b does not include:

* Advanced dashboards
* Charts unless trivially useful
* Custom report builder
* Saved report views
* Scheduled report delivery
* Automated email reports
* Data warehouse
* GL export
* Accounting system integration
* Multi-store comparative analytics beyond basic store filters if available
* Predictive analytics
* Full BI-style drilldown
* Full POS command integration
* Report-specific framework migration

## Initial Report Set

### 1. POS Register Summary

Purpose:

Summarize a register session for cashier/manager reconciliation.

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
* Merchandise class
* Tax category
* Store
* Date/business date
* Optional product/variant drilldown later

Primary filters:

* Date range
* Store
* Department/subdepartment
* Merchandise class
* Transaction type

### 3. Tax Collected

Purpose:

Support tax review and reconciliation.

Should include:

* Taxable sales by tax category/rate
* Non-taxable/exempt sales
* Tax collected by rate
* Tax refunds
* Net tax collected
* Exemption reason summary if available
* Manual tax overrides

Primary filters:

* Date range
* Store
* Tax category
* Tax rate
* Exemption status

### 4. Discount Summary

Purpose:

Show markdowns, promotions, and approval-sensitive discount activity.

Should include:

* Line discounts
* Transaction/order discounts
* Discount reasons
* Discount amount
* Discount percentage where meaningful
* Supervisor approvals
* Discounts over threshold
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

### 7. Inventory Value Snapshot

Purpose:

Show estimated inventory value at a point in time or current value.

Should include:

* On hand quantity
* Retail value
* Cost value
* Moving average cost where available
* Department/subdepartment
* Merchandise class
* Store
* Inventory behavior
* Exclusions for non-inventory/service/stored-value items
* Negative on-hand exceptions
* Items with missing/unknown cost

Primary filters:

* Store
* Department/subdepartment
* Merchandise class
* Inventory behavior
* As-of date if supported
* Include/exclude negative quantities
* Include/exclude zero on-hand

Initial version may be a current snapshot if historical as-of valuation is not yet reliable.

### 8. Purchasing and Receiving Summary

Purpose:

Summarize vendor ordering and receiving activity.

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

### Print Behavior

Initial print support should focus on:

* POS register summary
* Tax collected
* Sales summary
* Inventory value snapshot

Print layouts should be clean, compact, and avoid interactive-only controls.

## Suggested Technical Architecture

Use a consistent report architecture.

Recommended structure:

```text
app/controllers/reports/
app/services/reports/
app/presenters/reports/ or app/models/reports/
app/views/reports/
app/views/reports/shared/
```

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
* Store/session/vendor/category filters where applicable
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

### Step 1 — Report Infrastructure

* Add Reports navigation.
* Add shared report layout/partials.
* Add shared filter/date range component.
* Add shared metric strip.
* Add shared report table conventions.
* Add print stylesheet hooks.

### Step 2 — POS/Register Reports

Build first because they validate core money, tender, tax, discount, and cash movement semantics.

* POS Register Summary
* Cash Drawer Activity
* Tax Collected
* Discount Summary

### Step 3 — Sales Reports

* Sales Summary by department/subdepartment
* Sales by merchandise class
* Sales by tax category

### Step 4 — Inventory and Purchasing Reports

* Inventory Value Snapshot
* Purchasing/Receiving Summary

### Step 5 — Customer/Buyback Operational Reports

* Buyback Summary
* Customer Request Queue/Status

## Acceptance Criteria

Phase 9b is complete when:

* Reports navigation exists.
* Each initial report has a documented purpose and filters.
* Reports use shared Phase 9a report UI components.
* Reports use standardized formatting for money, percentages, quantities, dates, and statuses.
* Reports respect documented inclusion/exclusion rules.
* POS register summary can be printed and used for reconciliation.
* Sales, tax, discount, and cash reports reconcile against POS transaction data.
* Inventory value report excludes non-inventory/service/stored-value items.
* Buyback report distinguishes cash paid from trade credit issued.
* Customer request report shows actionable queue status.
* Report query/service logic is tested.
* Report views do not contain complex business math.
* No report introduces new one-off button, table, filter, or metric styles without adding them to the shared report/component standard.

## Deferred Reporting Features

Defer until after Phase 9b:

* Charts and graphs
* Saved report views
* Scheduled reports
* CSV/export automation unless simple
* GL/accounting export
* Report builder
* Multi-period trend dashboards
* Advanced drilldown
* Role-specific dashboards
* Email delivery
* Forecasting/predictive metrics

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
