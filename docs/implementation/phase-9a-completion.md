# Phase 9a — UX Foundation for Reporting

**Status:** Complete

## Deliverables

### Specifications

- [docs/specifications/phase-9a-ux-foundation-for-reporting-spec.md](../specifications/phase-9a-ux-foundation-for-reporting-spec.md) — master spec, CSS audit, helper API, shell acceptance (shells superseded in 9b)
- [docs/specifications/report-view-contract.md](../specifications/report-view-contract.md) — canonical report layout regions and print rules
- [docs/specifications/reporting-semantics.md](../specifications/reporting-semantics.md) — operational vs financial semantics, inclusion rules, procurement path
- [docs/specifications/phase-9a-test-plan.md](../specifications/phase-9a-test-plan.md)

### Report formatting helpers

- `ReportsHelper` with `format_report_money`, `format_report_basis_points`, `format_report_quantity`, `format_report_date`, `report_date_basis_label`, `report_print_button`
- Included in `ApplicationHelper`
- Signed money convention: `- $4.50` for report helpers; embedded POS report partials may still use `pos_report_signed_money` (parentheses) until those partials migrate

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

### Sample report shells (superseded in Phase 9b)

Phase 9a shipped two proof-of-contract shells. Phase 9b replaced them with live reports and removed shell controllers:

| 9a shell route | 9b replacement |
| -------------- | -------------- |
| `/reports/shells/reconciliation` | `/reports/tax_collected` (302 redirect) |
| `/reports/shells/queue` | `/reports/customer_requests` (302 redirect) |

The deprecated `reports.foundation.view` permission and `Seeds::Phase9aPermissions` seed module were removed in 9b.

## Verification

```bash
./dev/rails-docker bin/rails test \
  test/helpers/reports_helper_test.rb \
  test/services/reports/procurement_path_resolver_test.rb \
  test/services/reports/inclusion_rules_test.rb
```

Manual (post-9b):

1. Visit `/reports/tax_collected` — confirm filter bar, metric strip, rate/category table, and print action.
2. Visit `/reports/customer_requests` — confirm status badges and item drill-down links.
3. Confirm `/reports/shells/reconciliation` redirects to `/reports/tax_collected`.

## Known gaps (deferred at 9a close; addressed or still open)

- **Addressed in 9b:** Report migration, Reports hub, live operational queries
- **Phase 9c:** Financial posting layer — **deferred**
- **Phase 10:** Modal/drawer/POS command UX; item cockpit interaction patterns
- **Remaining:** POS partials embedded in migrated reports still use `pos_report_signed_money` in some revenue/drawer tables

## Next phase

Phase **9b** — operational reports. See [phase-9b-completion.md](phase-9b-completion.md).

Phase **9c** (financial posting layer) is documented but **deferred**. See [phase-9c-gl-shaped-financial-layer.md](../roadmap/phase-9c-gl-shaped-financial-layer.md).
