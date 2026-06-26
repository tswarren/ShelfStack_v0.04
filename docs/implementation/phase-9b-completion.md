# Phase 9b — Operational Reports

**Status:** Complete

## Deliverables

### Specifications

- [phase-9b-operational-reports-spec.md](../specifications/phase-9b-operational-reports-spec.md)
- [phase-9b-test-plan.md](../specifications/phase-9b-test-plan.md)
- Extended [reporting-semantics.md](../specifications/reporting-semantics.md) with per-report scopes

### Reports hub

- `Reports::Registry` — report catalog with permission-union hub visibility
- `Reports::IndexController` at `/reports`
- Main nav Reports link when user can open ≥1 report
- No separate `reports.access` permission

### Migrated reports (canonical `/reports/*`)

| Report | Route | Notes |
| ------ | ----- | ----- |
| Register Summary | `/reports/register_summary` | Reuses POS register partials in `ss-report` shell |
| Sales Summary | `/reports/sales_summary` | CSV export preserved |
| Cash Drawer | `/reports/cash_drawer` | |
| Sales / Returns lists | `/reports/sales`, `/reports/returns` | CSV export preserved |
| Operational Margin | `/reports/operational_margin` | |
| Buyback Summary | `/reports/buyback_summary` | |
| Stored Value Liability | `/reports/stored_value` | Date filter UI added |

### Greenfield reports

- Tax Collected — `Reports::TaxCollected::Query`
- Discount Summary — `Reports::DiscountSummary::Query`
- Inventory Value Snapshot — `Reports::InventoryValue::Query`
- Purchasing & Receiving Summary — `Reports::PurchasingSummary::Query`
- Customer Request Queue — `Reports::CustomerRequests::Query` (shared with workspace metrics)

### Legacy redirects (302)

- `/pos/reports/*` → canonical `/reports/*`
- `/buybacks/reports` → `/reports/buyback_summary`
- `/customers/stored_value_reports` → `/reports/stored_value`
- 9a shells → tax collected / customer requests

### Removed

- 9a shell controllers, presenters, views
- `Seeds::Phase9aPermissions` from seed run (`reports.foundation.view` deprecated)

## Verification

```bash
./dev/rails-docker bin/rails test \
  test/services/reports/ \
  test/integration/reports/ \
  test/helpers/reports_helper_test.rb
```

Manual:

1. Visit `/reports` as manager — grouped report links
2. Visit `/reports/register_summary` — print preview, session filter
3. Visit `/reports/tax_collected` — metric strip and tax source table
4. Confirm `/pos/reports/register_summary` redirects to canonical URL

## Known gaps (deferred)

- **Phase 9c:** GL posting and financial tie-out sections
- Historical inventory as-of valuation
- Advanced purchasing discrepancy analytics
- Full workspace customer-request table replacement with report-only layout

## Next phase

Phase **9c** — GL-shaped financial layer. See [phase-9c-gl-shaped-financial-layer.md](../roadmap/phase-9c-gl-shaped-financial-layer.md).
