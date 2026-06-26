# Report View Contract

Roadmap: [phase-9a-ux-foundation-for-reporting.md](../roadmap/phase-9a-ux-foundation-for-reporting.md)

Master spec: [phase-9a-ux-foundation-for-reporting-spec.md](phase-9a-ux-foundation-for-reporting-spec.md)

Item drill-down links: [phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md)

---

## Purpose

Define the canonical layout for ShelfStack operational and financial report screens. Phase 9b reports and Phase 9c export admin screens should follow this contract.

---

## Layout regions

Reports compose these regions top to bottom:

```text
Report header       — name, scope/subtitle, print/export actions
Filter bar          — date range and applicable filters; Run/Reset
Metric strip        — key totals, counts, exceptions (optional)
Section notices     — non-blocking notes (optional)
Report body         — tables grouped by operational meaning
Empty state         — when no rows match filters
Print layout        — letter-friendly output; hide interactive controls
```

### Report header

* Use `reports/shared/header` or `shared/forms/page_header` with report-specific scope line.
* Primary actions live in `ss-report-actions` (print, CSV export when available).
* Show active date basis or session scope in subtitle when applicable.

### Filter bar

* Wrap filters in `ss-filter-bar` with `ss-filter-group` and `ss-filter-actions`.
* Date ranges use `ss-date-range`.
* Select fields use standard `ss-field` / `ss-select` styling.
* Include **Run report** (submit) and **Reset** where useful.

### Metric strip

* Use `ss-metric-strip` and `ss-metric-card`.
* Numeric values use `ss-num` and report formatting helpers.
* Metrics appear before detail tables.

### Report body

* Tables use `ss-table ss-table--report` (optionally `ss-table--compact`).
* Money, quantity, and percentage columns use `ss-num`, `ss-money`, or `ss-percent`.
* Subtotal and total rows use `ss-table-row--subtotal` and `ss-table-row--total`.
* Empty table placeholder rows may use `ss-empty-row`.

### Empty state

* Use `ss-empty-state` with a clear title and explanation.
* Distinguish “no data in system” from “filters too narrow” when possible.

### Print

* Root wrapper: `ss-report report-print`.
* Interactive controls use `ss-report-no-print` (or existing `ss-pos-no-print` during POS migration).
* Print stylesheet hides filter bars and action buttons.

---

## Behavior rules

* Filters visible and understandable; active scope reflected in header.
* Totals before detail where practical.
* Right-align numeric columns.
* Avoid large alert banners for ordinary no-data conditions; use empty states or section notices.
* Report links to items use drill-down contract URLs; read-only navigation only.
* Do not embed complex business math in views; use query/presenter layers.

---

## Partial map

| Region | Partial |
| ------ | ------- |
| Layout wrapper | `reports/shared/layout` |
| Header | `reports/shared/header` |
| Filters | `reports/shared/filter_bar`, `reports/shared/date_range` |
| Metrics | `reports/shared/metric_strip` |
| Empty | `reports/shared/empty_state` |
| Notice | `reports/shared/section_notice` |

---

## Out of scope

Dashboard widgets, charts, saved views, drill-down write actions, modal/drawer interaction patterns (Phase 10).
