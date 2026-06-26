# Phase 9a — UX Foundation for Reporting

**Status:** Complete

## Deliverables

### Specifications

- [docs/specifications/phase-9a-ux-foundation-for-reporting-spec.md](../specifications/phase-9a-ux-foundation-for-reporting-spec.md) — master spec, CSS audit, helper API, shell acceptance
- [docs/specifications/report-view-contract.md](../specifications/report-view-contract.md) — canonical report layout regions and print rules
- [docs/specifications/reporting-semantics.md](../specifications/reporting-semantics.md) — operational vs financial semantics, inclusion rules, procurement path
- [docs/specifications/phase-9a-test-plan.md](../specifications/phase-9a-test-plan.md)

### Report formatting helpers

- `ReportsHelper` with `format_report_money`, `format_report_basis_points`, `format_report_quantity`, `format_report_date`, `report_date_basis_label`, `report_print_button`
- Included in `ApplicationHelper`
- Signed money convention: `- $4.50` (POS parentheses format unchanged until 9b migration)

### CSS primitives

Added to `shelfstack.css`:

- Layout/actions: `ss-report-actions`, `ss-filter-bar`, `ss-filter-group`, `ss-filter-actions`, `ss-date-range`
- Tables: `ss-table--report`, `ss-table--compact`, `ss-table-row--subtotal`, `ss-table-row--total`, `ss-empty-row`
- Numeric utilities: `ss-money`, `ss-percent`
- Messages: `ss-section-notice`, `ss-inline-note`
- Print: generalized `.ss-report.report-print` rules; hide `.ss-report-no-print` and `.ss-filter-bar` when printing
- Status badges: `ss-status-badge` remains the badge implementation (no parallel `ss-badge`)

### Shared report partials

Under `app/views/reports/shared/`:

- `_header.html.erb`, `_filter_bar.html.erb`, `_date_range.html.erb`, `_metric_strip.html.erb`
- `_empty_state.html.erb`, `_section_notice.html.erb`, `_layout.html.erb`

### Derived semantics services

- `Reports::ProcurementPathResolver` — derived procurement path (no DB column)
- `Reports::InclusionRules` — documented query scopes for Phase 9b report objects

### Sample report shells

- `Reports::ShellsController` at `/reports/shells/reconciliation` and `/reports/shells/queue`
- Placeholder presenters: `Reports::Shells::ReconciliationPresenter`, `Reports::Shells::QueuePresenter`
- Permission: `reports.foundation.view` (seeded via `Seeds::Phase9aPermissions`, granted to `pos_manager`)

## Verification

```bash
./dev/rails-docker bin/rails test \
  test/helpers/reports_helper_test.rb \
  test/services/reports/ \
  test/integration/reports_shells_controller_test.rb
```

Manual:

1. Grant `reports.foundation.view` (or log in as a user with `pos_manager` role after seed).
2. Visit `/reports/shells/reconciliation` — confirm filter bar, metric strip, grouped table with total row, print button.
3. Visit `/reports/shells/queue` — confirm status badges and item drill-down links.
4. Visit `/reports/shells/queue?empty=1` — confirm empty-state partial.

## Known gaps (deferred)

- **Phase 9b:** Migrate existing `/pos/reports/*`, buyback reports, and stored value reports to shared contract; unified Reports hub navigation
- **Phase 9c:** Financial posting layer; no `financial_*` tables in 9a
- **Phase 10:** Modal/drawer/POS command UX; item cockpit interaction patterns
- POS report money still uses `pos_report_signed_money` parentheses format until 9b migration
- Shell presenters use placeholder data only — no live operational queries yet

## Next phase

Phase **9b** — operational report migration and Reports hub. See [docs/roadmap/phase-9b-reports.md](../roadmap/phase-9b-reports.md).
