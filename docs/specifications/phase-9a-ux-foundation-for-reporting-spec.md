# Phase 9a — UX Foundation for Reporting

Roadmap: [phase-9a-ux-foundation-for-reporting.md](../roadmap/phase-9a-ux-foundation-for-reporting.md)

Test plan: [phase-9a-test-plan.md](phase-9a-test-plan.md)

Related:

* [report-view-contract.md](report-view-contract.md)
* [reporting-semantics.md](reporting-semantics.md)
* [phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md)

**Prerequisite:** Phase 8.5-4 complete (item drill-down contract).

---

## 1. Purpose

Establish report-facing UX standards, formatting helpers, reporting semantics, shared partials, and two proof-of-contract report shells before Phase 9b operational reports and Phase 9c financial postings.

No migration of existing POS/buyback/stored-value reports in this phase.

---

## 2. CSS / component audit

| Class / pattern | Status | Notes |
| --------------- | ------ | ----- |
| `ss-page-header`, `ss-page-actions` | Exists | `shared/forms/page_header` |
| `ss-main`, `ss-section`, `ss-card`, `ss-panel` | Exists | Reuse |
| `ss-empty-state` | Exists | |
| `ss-metric-strip`, `ss-metric-card` | Exists | `orders/shared/metric_strip` |
| `ss-status-badge` | Exists | Roadmap “badge”; do not add parallel `ss-badge` |
| `ss-table`, `ss-num` | Exists | |
| `ss-btn`, `ss-form`, `ss-field` | Exists | |
| `ss-filter-bar`, `ss-filter-group`, `ss-filter-actions` | **Added 9a** | |
| `ss-date-range` | **Added 9a** | |
| `ss-report-actions` | **Added 9a** | |
| `ss-table--report`, `ss-table--compact` | **Added 9a** | |
| `ss-table-row--subtotal`, `ss-table-row--total`, `ss-empty-row` | **Added 9a** | |
| `ss-money`, `ss-percent` | **Added 9a** | Numeric column helpers |
| `ss-section-notice`, `ss-inline-note` | **Added 9a** | |
| `ss-report`, `report-print` | **Extended 9a** | Shared print baseline |
| POS register summary print | Exists | Migrate to shared contract in 9b |

---

## 3. Formatting helpers (`ReportsHelper`)

Included via `ApplicationHelper`.

| Method | Convention |
| ------ | ---------- |
| `format_report_money(cents, signed: false)` | `$12.99`; signed uses `- $4.50` prefix |
| `format_report_basis_points(bps)` | `6.25%` |
| `format_report_quantity(qty)` | Whole numbers; `—` for nil |
| `format_report_date(time, basis:, format: :short)` | Timestamp with optional basis label |
| `report_date_basis_label(basis)` | Human label for date basis key |

POS `pos_report_signed_money` (parentheses negatives) remains until 9b migration.

---

## 4. Shared partials

Path: `app/views/reports/shared/`

See [report-view-contract.md](report-view-contract.md).

---

## 5. Services

### `Reports::ProcurementPathResolver`

Derived procurement path for variants/lines. No DB column.

### `Reports::InclusionRules`

Query scopes for 9b reports (POS completed, buyback completed, inventory ledger, etc.).

---

## 6. Sample report shells

Routes:

```text
GET /reports/shells/reconciliation
GET /reports/shells/queue
```

Permission: `reports.foundation.view`

| Shell | Proves |
| ----- | ------ |
| Reconciliation | Metrics, signed money, subtotal/total rows, date filter, print |
| Queue | Status badges, aging, filters, item drill-down links, empty state |

Placeholder data only; no production query logic.

---

## 7. Out of scope

Unified Reports nav (9b), existing report migration (9b), financial postings (9c), modal/drawer/POS workspace (Phase 10), `procurement_path` persistence, dashboards/charts.

---

## 8. Acceptance

Matches roadmap Phase 9a acceptance criteria: two shells, semantics documented, helpers and CSS gaps filled, drill-down contract referenced.
