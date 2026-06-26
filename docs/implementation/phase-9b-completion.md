# Phase 9b — Operational Reports

**Status:** Complete

## Deliverables

### Specifications

- [phase-9b-operational-reports-spec.md](../specifications/phase-9b-operational-reports-spec.md)
- [phase-9b-test-plan.md](../specifications/phase-9b-test-plan.md)
- Extended [reporting-semantics.md](../specifications/reporting-semantics.md) with per-report scopes and tax report structure

### Reports hub

- `Reports::Registry` — report catalog with permission-union hub visibility
- `Reports::IndexController` at `/reports`
- Main nav Reports link when user can open ≥1 report
- No separate `reports.access` permission

### Migrated reports (canonical `/reports/*`)

| Report | Route | Notes |
| ------ | ----- | ----- |
| Register Summary | `/reports/register_summary` | Reuses POS register partials in `ss-report` shell |
| Sales Summary | `/reports/sales_summary` | CSV export preserved; `filter_type`-aware scope |
| Cash Drawer | `/reports/cash_drawer` | Accepts `session_id` or `register_session_id` |
| Sales / Returns lists | `/reports/sales`, `/reports/returns` | Sales list is `transaction_type: sale` only; CSV preserved |
| Operational Margin | `/reports/operational_margin` | |
| Buyback Summary | `/reports/buyback_summary` | |
| Stored Value Liability | `/reports/stored_value` | Date filter UI added |

### Greenfield reports

- **Tax Collected** — `Reports::TaxCollected::Query` with summary metrics, rate/category rollup (snapshot-first labels), and exemptions/overrides section
- Discount Summary — `Reports::DiscountSummary::Query`
- Inventory Value Snapshot — `Reports::InventoryValue::Query`
- Purchasing & Receiving Summary — `Reports::PurchasingSummary::Query`
- Customer Request Queue — `Reports::CustomerRequests::Query` (shared with workspace metrics; full match count with 100-row display cap)

### Scope and redirect fixes

- `Pos::ReportScope.from_params` respects `filter_type` (register session, business date, date range)
- Legacy POS redirects normalize `session_id` → `register_session_id`
- Cash drawer accepts both param names after redirect

### Legacy redirects (302)

- `/pos/reports/*` → canonical `/reports/*`
- `/buybacks/reports` → `/reports/buyback_summary`
- `/customers/stored_value_reports` → `/reports/stored_value`
- 9a shells → tax collected / customer requests

### Removed

- 9a shell controllers, presenters, views, and integration tests
- `Seeds::Phase9aPermissions` seed module and `reports.foundation.view` permission seed path

## Verification

```bash
./dev/rails-docker bin/rails test \
  test/services/reports/ \
  test/integration/reports/ \
  test/helpers/reports_helper_test.rb \
  test/integration/pos_reports_controller_test.rb
```

Manual:

1. Visit `/reports` as manager — grouped report links for permitted reports only
2. Visit `/reports/register_summary` — print preview, session filter, POS partials in report shell
3. Visit `/reports/tax_collected` — summary metric strip, rate/category table, exemptions section
4. Submit sales summary with `filter_type=date_range` while `business_date` is present — scope label shows date range, not business date
5. Confirm `/pos/reports/register_summary?session_id=…` redirects and preserves session on canonical routes

## Known gaps (deferred)

- **Phase 9c:** GL posting and financial tie-out sections — **deferred**
- Line-level tax audit drill-down on Tax Collected
- Historical inventory as-of valuation
- Advanced purchasing discrepancy analytics
- Full workspace customer-request table replacement with report-only layout
- Migrate embedded POS partial money formatting to `format_report_money`

## Next phase

Phase **10** — comprehensive UI/UX expansion. See [Phase-x10-comprehensive-ux-expansion.md](../roadmap/Phase-x10-comprehensive-ux-expansion.md).

Phase **9c** (GL-shaped financial layer) remains documented but **deferred**. See [phase-9c-gl-shaped-financial-layer.md](../roadmap/phase-9c-gl-shaped-financial-layer.md).
