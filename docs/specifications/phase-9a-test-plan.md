# Phase 9a Test Plan

Spec: [phase-9a-ux-foundation-for-reporting-spec.md](phase-9a-ux-foundation-for-reporting-spec.md)

---

## 1. ReportsHelper

* `format_report_money` — nil, zero, positive, signed negative
* `format_report_basis_points` — nil, typical bps
* `format_report_quantity` — nil, integer
* `format_report_date` — nil, with/without basis label
* `report_date_basis_label` — known keys

## 2. ProcurementPathResolver

* Buyback-created variant → `buyback`
* Buyback line donated / zero offer → `buyback_donation`
* Variant with vendor sourcing → `vendor_order`
* Financial / service / non-inventory product → `not_applicable`
* Physical variant without vendor, not buyback → `manual_stock`

## 3. InclusionRules

* `pos_sales_transactions` excludes draft/voided/cancelled
* `buyback_reportable_sessions` includes completed, excludes draft
* `inventory_ledger_entries` returns posted ledger rows

## 4. Report shells (integration)

* Unauthorized without `reports.foundation.view`
* Reconciliation shell renders contract regions: `ss-filter-bar`, `ss-metric-strip`, `ss-table--report`, print hook
* Queue shell renders status badges, item links, empty state when `empty=1`

## 5. Performance

Not applicable for placeholder shells.
