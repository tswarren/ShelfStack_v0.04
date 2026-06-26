# Phase 9a Test Plan

Spec: [phase-9a-ux-foundation-for-reporting-spec.md](phase-9a-ux-foundation-for-reporting-spec.md)

**Note:** Section 4 (shell integration tests) described Phase 9a proof shells removed in Phase 9b. Use [phase-9b-test-plan.md](phase-9b-test-plan.md) for live report integration coverage.

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

## 4. Report shells (historical — superseded by 9b)

Phase 9a integration tests for shells were removed when live reports shipped. Equivalent coverage lives in:

* `test/integration/reports/tax_collected_controller_test.rb`
* `test/integration/reports/customer_requests_controller_test.rb`
* `test/integration/reports/redirects_controller_test.rb` (shell route redirects)

## 5. Performance

Not applicable for placeholder shells.
