# Phase 9a — UX Foundation for Reporting

## Purpose

Phase 9a prepares ShelfStack for the reporting phase by standardizing the minimum user-interface patterns, formatting rules, and reporting semantics needed to build trustworthy reports.

This phase is intentionally limited. It is not the full ShelfStack UX redesign. It does not attempt to complete the POS command workspace, full item cockpit redesign, global drawer system, or advanced modal rollout. Instead, it creates the foundation reports need: consistent page structure, filters, tables, metrics, messages, money/date/status formatting, and report inclusion rules.

## Problem Statement

ShelfStack already has strong operational coverage, but many screens currently solve layout, buttons, fields, alerts, filters, and focus behavior differently. Reports will amplify these inconsistencies because report screens rely heavily on:

* Date range controls
* Filter bars
* Metric cards
* Tables
* Numeric alignment
* Status labels
* Empty states
* Print/export actions
* Money, quantity, percentage, and tax formatting
* Inclusion/exclusion rules for draft, cancelled, completed, voided, returned, posted, and closed records

If reports are built before these conventions are defined, the reporting layer will likely become another set of one-off screens.

## Goals

Phase 9a should:

1. Define the minimum ShelfStack UX standards needed before reports.
2. Standardize report-facing UI components.
3. Standardize money, percentage, quantity, date, and status formatting.
4. Define reporting semantics for core operational records.
5. Clarify item behavior and procurement distinctions that affect reporting.
6. Prepare POS/register data for register summary reporting.
7. Establish a report view contract that Phase 9b can reuse.
8. Avoid delaying reports with the full long-term UX vision.

## Non-Goals

Phase 9a does not include:

* Full POS command registry
* Function-key system
* Full command palette
* Drawers throughout the application
* Full item cockpit redesign
* Full POS transaction-first routing overhaul
* Complete modal system rollout
* Advanced dashboards
* Charts and visual analytics
* Saved report views
* Custom report builder
* Scheduled reports
* Full RubyUI/DaisyUI/framework migration
* Offline POS
* A reporting data warehouse

## Scope

### 1. UX Direction and View Contracts

Create or update documentation defining ShelfStack’s UX direction:

* Operational, not decorative
* Fast, not flashy
* Dense enough for bookstore work, but not cramped
* Keyboard-friendly by default
* Clear primary action on every screen
* Summary first, detail on demand
* Brand colors used as accents, not visual noise
* Predictable fields, buttons, validation, focus, and feedback

Define or confirm view contracts for:

* Index/search
* Detail/overview
* Item overview
* Form/edit
* Workflow
* POS/register
* Report
* Setup list
* Modal
* Drawer

Phase 9a should make the **Report** view contract explicit.

### 2. Report View Contract

Create a standard report structure:

```text
Report header
  Report name
  Scope/date range
  Print/export actions

Filter bar
  Date range
  Store/register/user/vendor/category filters as applicable
  Run/update action
  Reset action where useful

Metric strip
  Key totals
  Counts
  Exceptions

Report body
  Tables grouped by operational meaning
  Detail rows
  Subtotals
  Notes/exceptions

Empty state
  Clear explanation when no data matches

Print layout
  Clean, letter-friendly output where applicable
```

Report screens should prioritize correctness, readability, reconciliation, and printability over visual analytics.

### 3. Core UI Component Standards

Standardize or refine the following shared components before reports are built:

#### Page and Layout

* `ss-page-header`
* `ss-page-actions`
* `ss-main`
* `ss-main--wide`
* `ss-section`
* `ss-panel`
* `ss-card`
* `ss-sidebar`
* `ss-empty-state`

#### Buttons and Actions

* `ss-btn`
* `ss-btn--primary`
* `ss-btn--secondary`
* `ss-btn--neutral`
* `ss-btn--danger`
* `ss-btn--ghost`
* `ss-btn--link`
* `ss-btn--sm`
* `ss-btn--lg`
* `ss-btn--block`
* `ss-action-group`
* `ss-form-actions`
* `ss-row-actions`
* `ss-report-actions`

The base button class should not own page spacing. Spacing belongs to layout/action containers.

#### Forms and Filters

* `ss-form`
* `ss-field`
* `ss-label`
* `ss-input`
* `ss-select`
* `ss-textarea`
* `ss-help`
* `ss-field-error`
* `ss-filter-bar`
* `ss-filter-group`
* `ss-filter-actions`
* `ss-date-range`
* `ss-search-field`

Select lists should visually match other fields. Report filters should not look like unrelated raw browser controls.

#### Tables and Numeric Layout

* `ss-table`
* `ss-table--compact`
* `ss-table--report`
* `ss-table-scroll`
* `ss-num`
* `ss-money`
* `ss-percent`
* `ss-actions-cell`
* `ss-table-row--subtotal`
* `ss-table-row--total`
* `ss-empty-row`

Money, quantities, percentages, and totals should be right-aligned and formatted consistently.

#### Metrics and Status

* `ss-metric-strip`
* `ss-metric-card`
* `ss-metric-card__label`
* `ss-metric-card__value`
* `ss-metric-card__detail`
* `ss-badge`
* `ss-badge--success`
* `ss-badge--warning`
* `ss-badge--danger`
* `ss-badge--neutral`
* `ss-badge--info`

Badges should communicate status. They should not look like primary actions.

#### Messages

* `ss-flash-region`
* `ss-flash`
* `ss-flash--success`
* `ss-flash--warning`
* `ss-flash--error`
* `ss-flash--info`
* `ss-attention-panel`
* `ss-section-notice`
* `ss-workflow-alert`
* `ss-inline-note`
* `ss-field-error`

Reports should use empty states and section notices rather than large alert banners for ordinary “no data” conditions.

### 4. Formatting Standards

Define helpers and conventions for:

#### Currency

* Display as decimal dollars.
* Store internally as cents where applicable.
* Right-align currency columns.
* Use consistent negative/refund formatting.
* Avoid exposing raw `_cents` fields to users.

Examples:

```text
$12.99
-$4.50
($4.50) only if this is chosen as the report convention
```

#### Percentages

* Display as decimal percentages.
* Store internally as basis points where applicable.
* Avoid exposing raw `bps` values to users.

Examples:

```text
6.25%
10.00%
```

#### Quantities

* Display whole quantities without unnecessary decimals.
* Right-align quantity columns.
* Distinguish counts from monetary totals.

#### Dates and Times

Define when to use:

* Business date
* Calendar date
* Timestamp
* Posted at
* Completed at
* Created at
* Updated at
* Closed at

Reports should make their date basis clear.

Examples:

```text
Sales reports use completed/business date.
Inventory movement reports use posted_at.
Audit views use created_at.
Register summaries use register session boundaries.
```

### 5. Reporting Semantics

Define inclusion/exclusion rules before Phase 9b.

#### POS Transactions

Clarify how reports treat:

* Draft transactions
* Completed transactions
* Cancelled transactions
* Voided transactions
* Returns
* Exchanges
* Refunds
* Suspended/held transactions

Minimum rule:

```text
Sales totals include completed transactions only.
Draft, cancelled, and voided transactions are excluded from sales totals unless a specific exception/audit report includes them.
```

#### Register Sessions

Clarify how reports treat:

* Open sessions
* Closed sessions
* Cash paid in
* Cash paid out
* Cash drops
* Cash refunds
* Expected drawer
* Counted drawer
* Over/short

#### Buybacks

Clarify how reports treat:

* Draft buybacks
* Quoted buybacks
* Accepted/completed buybacks
* Rejected lines
* Cash payout
* Trade credit payout
* Inventory posted from buyback
* Records marked `needs_review`

#### Purchasing and Receiving

Clarify how reports treat:

* Draft purchase orders
* Submitted/ordered purchase orders
* Partially received purchase orders
* Closed purchase orders
* Receipt lines
* Accepted quantity
* Rejected/damaged quantity
* Backordered quantity
* Return to vendor records

Minimum rule:

```text
Inventory value and movement reports use posted inventory ledger entries, not unposted PO or receipt drafts.
```

#### Customer Requests

Clarify how reports treat:

* Open requests
* Completed requests
* Cancelled requests
* Ready for pickup
* Awaiting customer response
* Special order demand
* TBO demand
* Holds/reserves

#### Stored Value and Gift Cards

Clarify:

* Gift card sale creates liability, not ordinary merchandise revenue.
* Gift card redemption reduces liability and applies payment.
* Trade credit issuance creates stored value liability.
* Trade credit redemption applies payment.
* Stored value adjustments should be separately reportable.

### 6. Item Behavior and Procurement Path

Define reporting-relevant item behavior before reports.

Minimum behavior profiles:

* New/vendor-order stock
* Used/buyback stock
* Donation/manual stock
* Sideline/vendor-order stock
* Café/prepared item
* Service/fee
* Gift card/stored value
* Digital/non-physical item
* Non-inventory item

Define procurement path values:

```text
vendor_order
buyback
donation
manual_stock
not_applicable
```

Reporting implications:

* Vendor-order stock appears in purchasing/vendor reports.
* Buyback stock appears in buyback/used inventory reports.
* Used/buyback variants should not be treated as incomplete because they lack vendor sources.
* Non-inventory/service/stored-value items should not be included in inventory value reports.
* Gift cards and stored value should be treated as liability activity, not ordinary merchandise sales.

### 7. POS/Register Reporting Readiness

Before Phase 9b, confirm:

* Tender type categories
* Cash movement categories
* Refund handling
* Tax subtotal rules
* Discount subtotal rules
* Gift card sale/redemption treatment
* Store credit issue/redemption treatment
* Register session inclusion rules
* Register summary print layout requirements

Phase 9a does not need the full POS command registry, but POS data must be semantically ready for reporting.

### 8. Documentation Deliverables

Create or update documentation:

```text
docs/specifications/phase-9a-ux-foundation-for-reporting.md
docs/specifications/view-contracts.md
docs/specifications/reporting-semantics.md
docs/specifications/report-view-contract.md
docs/specifications/ui-components.md
```

If preferred, some of these can be sections in a single Phase 9a document rather than separate files.

## Suggested Implementation Order

1. Document target UX feel and view contracts.
2. Define report view contract.
3. Standardize buttons/actions and remove button spacing side effects.
4. Standardize forms/selects/filter bars.
5. Standardize tables, metric cards, badges, and empty states.
6. Standardize flash/notice/attention/message placement.
7. Add money/percentage/quantity/date formatting helpers.
8. Define reporting statuses and inclusion/exclusion rules.
9. Define item behavior profiles and procurement path.
10. Confirm POS/register reporting semantics.
11. Create one or two sample report shells using placeholder data to prove the layout.

## Acceptance Criteria

Phase 9a is complete when:

* A report view contract is documented.
* Core report UI components exist or are standardized.
* Buttons, filters, tables, metrics, badges, and empty states have defined CSS classes.
* Select lists and form fields visually match the app’s standard field style.
* Money, percentage, quantity, and date formatting helpers are defined.
* Reportable status rules are documented for POS, register sessions, buybacks, purchasing/receiving, inventory, customer requests, and stored value.
* Item behavior profiles and procurement path are defined enough to prevent misleading reports.
* Gift card/stored value reporting treatment is documented.
* POS/register inclusion rules are clear enough to build a register summary.
* At least one report shell can be built without inventing new UI patterns.
* The full POS command/drawer/item cockpit vision remains explicitly deferred.

## Risks

### Scope Creep

Phase 9a can easily expand into the full UX overhaul. Keep it bounded to reporting-facing standards and semantics.

### Premature Framework Migration

Do not migrate to a new UI framework during Phase 9a unless it is a separately approved decision. The current `ss-*` system can be standardized first.

### Incomplete Semantics

Reports built on unclear status/date/tax/tender rules will look polished but produce misleading totals.

### Over-Designing Reports

Initial reports should be accurate and printable before they become dashboards.