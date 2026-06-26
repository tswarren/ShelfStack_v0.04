# Phase 9a — UX Foundation for Reporting

Part of [Phase 9 — Reporting and Accounting](phase-9-reporting-and-accounting.md).

## Purpose

Phase 9a prepares ShelfStack for operational and financial reporting by standardizing the report-facing user-interface patterns, formatting rules, and reporting semantics needed to build trustworthy reports.

Phase 9a implements the **report-facing subset** of the ShelfStack UX direction. It does not complete the comprehensive interaction system. That work belongs in [Phase 10 — Comprehensive UI/UX Expansion](Phase-x10-comprehensive-ux-expansion.md).

This phase is intentionally limited. It does not attempt to complete the POS command workspace, full item cockpit redesign, global drawer system, modal rollout, or advanced workflow UX. Instead, it creates the foundation reports need: consistent page structure, filters, tables, metrics, messages, money/date/status formatting, inclusion/exclusion rules, and operational-vs-financial reporting semantics.

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

1. Define the minimum report-facing UX standards needed before Phase 9b and 9c.
2. Standardize report-facing UI components.
3. Standardize money, percentage, quantity, date, and status formatting.
4. Define reporting semantics for core operational records.
5. Define operational vs financial reporting semantics.
6. Clarify item behavior and procurement-path distinctions that affect reporting.
7. Prepare POS/register data for register summary reporting.
8. Establish a report view contract that Phase 9b can reuse.
9. Avoid delaying reports with the full long-term UX vision.

## Non-Goals

Phase 9a does not include:

* Full POS command registry
* Function-key system
* Full command palette
* Drawers throughout the application
* Full item cockpit redesign
* Full POS transaction-first routing overhaul
* Complete modal system rollout
* Full workflow UX contracts (Index, Form, Workflow, POS workspace, Modal, Drawer)
* Advanced dashboards
* Charts and visual analytics
* Saved report views
* Custom report builder
* Scheduled reports
* GL-shaped financial postings or export (Phase 9c)
* Full RubyUI/DaisyUI/framework migration
* Offline POS
* A reporting data warehouse

Modal, drawer, POS workspace, and full item cockpit contracts belong in Phase 10. Phase 9a may **reference** [ui-ux-concept.md](../specifications/ui-ux-concept.md) for broader direction but must not redefine or implement those systems.

## Scope

### 1. UX Direction (Report-Facing Subset)

Reference [ui-ux-concept.md](../specifications/ui-ux-concept.md) for the long-term ShelfStack UX direction. Phase 9a codifies only what reports need:

* Operational, not decorative
* Fast, not flashy
* Dense enough for bookstore work, but not cramped
* Clear primary action on every screen
* Summary first, detail on demand
* Brand colors used as accents, not visual noise
* Predictable fields, buttons, validation, and feedback on report screens

Phase 9a must make the **Report** view contract explicit. Item report drill-down must follow [phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md) from Phase 8.5-4; do not redefine the item overview cockpit here.

### 2. Report View Contract

Create a standard report structure:

```text
Report header
  Report name
  Scope/date range
  Print/export actions

Filter bar
  Date range
  Store/register/user/vendor/department/subdepartment filters as applicable
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

Do not treat this as a greenfield CSS rewrite. Phase 9a UI work should:

```text
1. Audit existing ss-* components and existing report screens.
2. Identify missing report-facing primitives.
3. Add only the missing classes/components needed for reports.
4. Migrate existing reports gradually as part of Phase 9b.
```

Many classes already exist (`ss-page-header`, `ss-metric-strip`, `ss-metric-card`, `ss-table`, `ss-num`, `ss-empty-state`). Report-specific classes may still need to be added (`ss-filter-bar`, `ss-date-range`, `ss-table--report`, `ss-report-actions`).

Standardize or refine the following shared components for reports:

#### Page and Layout

* `ss-page-header`
* `ss-page-actions`
* `ss-main`
* `ss-main--wide`
* `ss-section`
* `ss-panel`
* `ss-card`
* `ss-empty-state`

#### Buttons and Actions

* `ss-btn` and variants
* `ss-action-group`
* `ss-form-actions`
* `ss-report-actions`

The base button class should not own page spacing. Spacing belongs to layout/action containers.

#### Forms and Filters

* `ss-form`
* `ss-field`
* `ss-label`
* `ss-input`
* `ss-select`
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
* `ss-table-row--subtotal`
* `ss-table-row--total`
* `ss-empty-row`

Money, quantities, percentages, and totals should be right-aligned and formatted consistently.

#### Metrics and Status

* `ss-metric-strip`
* `ss-metric-card` and sub-elements
* `ss-badge` and variants

Badges should communicate status. They should not look like primary actions.

#### Messages

* `ss-flash-region` and flash variants
* `ss-attention-panel`
* `ss-section-notice`
* `ss-inline-note`

Reports should use empty states and section notices rather than large alert banners for ordinary “no data” conditions.

### 4. Formatting Standards

Define helpers and conventions for:

#### Currency

* Display as decimal dollars.
* Store internally as cents where applicable.
* Right-align currency columns.
* Use consistent negative/refund formatting.
* Avoid exposing raw `_cents` fields to users.
* Consolidate scattered helpers (e.g. `format_cents`) into report-facing conventions.

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

### 5. Operational vs Financial Reporting Semantics

Phase 9a defines how operational and financial reporting differ. Phase 9b primarily uses operational sources; Phase 9c introduces financial postings.

| Concern | Operational reporting (9b) | Financial reporting (9c) |
| ------- | -------------------------- | ------------------------ |
| Primary source | POS snapshots, ledgers, workflow tables | `financial_entries` and lines |
| Gift card sale | Liability activity in stored-value ledger | Credit gift card liability account |
| Sales total | Completed POS transaction totals | Revenue accounts from posted entries |
| Inventory value | Inventory balances / ledger | Inventory asset accounts when posted |
| Reconciliation | POS/register/inventory tie-out | Operational totals vs financial entries |

Rules:

* Operational reports may ship before Phase 9c is complete.
* Financial reports and GL export require Phase 9c posted entries.
* Hybrid reports (e.g. register summary) may combine operational context with financial tie-out after 9c.
* Phase 9c posting rules must follow the inclusion/exclusion semantics defined here.

### 6. Reporting Semantics

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

POS tax and discount reports should use Phase 8.5-1/8.5-2 snapshot fields (`pos_discount_applications`, `normal_tax_cents`, `applied_tax_source`) where applicable, not live catalog joins.

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
* Donated / zero-value lines
* Cash payout
* Trade credit payout
* Inventory posted from buyback
* Voided completed buybacks
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

### 7. Item Behavior and Procurement Path

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

#### Procurement Path (Derived Reporting Dimension)

Phase 9a defines procurement path as a **reporting dimension**. It may be derived from existing records unless a later schema decision persists it. Phase 9c may use the same dimension for accounting mappings.

Phase 9a does **not** require adding a persisted `procurement_path` column. Persistence should be a separate schema decision only if derived resolution proves insufficient or too expensive.

Values:

```text
vendor_order
buyback
donation
buyback_donation
manual_stock
not_applicable
```

Example derived rules:

| Condition | Derived procurement path |
| --------- | ------------------------ |
| Variant with vendor source / orderable | `vendor_order` |
| Variant created through buyback | `buyback` |
| Accepted buyback line with zero offer / donation | `buyback_donation` or `donation` |
| Manual inventory setup | `manual_stock` |
| Gift card / service / non-inventory | `not_applicable` |

Reporting implications:

* Vendor-order stock appears in purchasing/vendor reports.
* Buyback stock appears in buyback/used inventory reports.
* Used/buyback variants should not be treated as incomplete because they lack vendor sources.
* Non-inventory/service/stored-value items should not be included in inventory value reports.
* Gift cards and stored value should be treated as liability activity, not ordinary merchandise sales.

### 8. POS/Register Reporting Readiness

Before Phase 9b, confirm:

* Tender type categories
* Cash movement categories
* Refund handling
* Tax subtotal rules (including exemption and line override snapshots)
* Discount subtotal rules (including structured discount applications)
* Gift card sale/redemption treatment
* Store credit issue/redemption treatment
* Register session inclusion rules
* Register summary print layout requirements

Phase 9a does not need the full POS command registry, but POS data must be semantically ready for reporting.

### 9. Documentation Deliverables

Create or update documentation:

```text
docs/specifications/phase-9a-ux-foundation-for-reporting-spec.md
docs/specifications/report-view-contract.md
docs/specifications/reporting-semantics.md
```

Reference, do not duplicate:

```text
docs/specifications/ui-ux-concept.md
docs/handoff/phase-9-item-drill-down-contract.md
```

If preferred, some deliverables can be sections in a single Phase 9a specification rather than separate files.

## Suggested Implementation Order

1. Document report view contract and operational-vs-financial semantics.
2. Audit existing `ss-*` components and report screens; identify gaps.
3. Add missing report-facing CSS primitives only.
4. Standardize report filters, tables, metric cards, badges, and empty states.
5. Consolidate money/percentage/quantity/date formatting helpers.
6. Document reporting statuses and inclusion/exclusion rules.
7. Document item behavior profiles and derived procurement path rules.
8. Confirm POS/register reporting semantics (including 8.5-1/8.5-2 snapshots).
9. Create two sample report shells using placeholder data to prove the layout:
   * A reconciliation-style shell (e.g. POS Register Summary or Tax Collected)
   * An operational queue-style shell (e.g. Customer Request Queue or Buyback Summary)

## Acceptance Criteria

Phase 9a is complete when:

* A report view contract is documented.
* Operational vs financial reporting semantics are documented.
* Core report UI components are audited; missing report-facing primitives are defined or added.
* Money, percentage, quantity, and date formatting helpers are defined.
* Reportable status rules are documented for POS, register sessions, buybacks, purchasing/receiving, inventory, customer requests, and stored value.
* Procurement path is documented as a derived reporting dimension with resolution rules (no persisted column required by default).
* Gift card/stored value reporting treatment is documented.
* POS/register inclusion rules are clear enough to build a register summary.
* Item drill-down contract from Phase 8.5-4 is referenced for report links.
* At least **two** report shells are proven without inventing new UI patterns: one reconciliation-style report and one operational queue-style report.
* Modal, drawer, POS workspace, and full item cockpit work remain explicitly deferred to Phase 10.

## Risks

### Scope Creep

Phase 9a can easily expand into the full UX overhaul. Keep it bounded to reporting-facing standards and semantics.

### Premature Framework Migration

Do not migrate to a new UI framework during Phase 9a unless it is a separately approved decision. The current `ss-*` system can be standardized first.

### Incomplete Semantics

Reports built on unclear status/date/tax/tender rules will look polished but produce misleading totals.

### Over-Designing Reports

Initial reports should be accurate and printable before they become dashboards.

## Related Documents

```text
docs/roadmap/phase-9-reporting-and-accounting.md
docs/roadmap/phase-9b-reports.md
docs/roadmap/phase-9c-gl-shaped-financial-layer.md
docs/roadmap/Phase-x10-comprehensive-ux-expansion.md
```
