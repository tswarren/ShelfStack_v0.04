# Phase 9b — Operational Reports

Roadmap: [phase-9b-reports.md](../roadmap/phase-9b-reports.md)

Test plan: [phase-9b-test-plan.md](phase-9b-test-plan.md)

Related:

* [phase-9a-ux-foundation-for-reporting-spec.md](phase-9a-ux-foundation-for-reporting-spec.md)
* [report-view-contract.md](report-view-contract.md)
* [reporting-semantics.md](reporting-semantics.md)

**Prerequisite:** Phase 9a complete.

---

## 1. Purpose

Deliver operational reports under a unified `/reports` hub using the Phase 9a view contract. Migrate existing report surfaces; add greenfield tax, discount, and purchasing reports.

No GL posting or financial export (Phase 9c).

---

## 2. Migration decisions

| Decision | Resolution |
| -------- | ---------- |
| Hub access | No `reports.access`. Nav visible when user can open ≥1 report (permission union). |
| Legacy URLs | 302 redirect to canonical `/reports/*`. |
| Customer queue | Shared query/presenter; workspace index adopts report-style layout. |
| Tax vs sales summary | Sales summary keeps high-level tax; Tax Collected is dedicated reconciliation. |
| Inventory as-of | Current snapshot only in MVP. |
| Purchasing MVP | Summary metrics + PO/receipt tables; defer discrepancy analytics. |
| Enterprise inventory | Section in inventory value report when `inventory.enterprise.view`. |
| Operational margin permission | Shares `pos.reports.summary` with revenue summary. |

---

## 3. Report catalog

| Report | Route | Permission | Service |
| ------ | ----- | ---------- | ------- |
| Register Summary | `/reports/register_summary` | `pos.reports.register_summary` | `Pos::SalesRegisterSummaryReport` |
| Cash Drawer | `/reports/cash_drawer` | `pos.reports.drawer` | `Pos::RegisterSessionSummary` |
| Sales Summary | `/reports/sales_summary` | `pos.reports.summary` | `Pos::SalesRevenueSummaryReport` |
| Sales List | `/reports/sales` | `pos.reports.sales` | `Reports::InclusionRules` |
| Returns List | `/reports/returns` | `pos.reports.returns` | `Reports::InclusionRules` |
| Operational Margin | `/reports/operational_margin` | `pos.reports.summary` | `Pos::OperationalMarginReport` |
| Tax Collected | `/reports/tax_collected` | `pos.reports.summary` | `Reports::TaxCollected::Query` |
| Discount Summary | `/reports/discount_summary` | `pos.reports.summary` | `Reports::DiscountSummary::Query` |
| Buyback Summary | `/reports/buyback_summary` | `buybacks.reports.view` | `Buybacks::ReportBuilder` |
| Stored Value Liability | `/reports/stored_value` | `stored_value.reports.view` | `StoredValue::LiabilityReport` |
| Inventory Value | `/reports/inventory_value` | `inventory.balances.view` | `Reports::InventoryValue::Query` |
| Purchasing Summary | `/reports/purchasing_summary` | `orders.access` | `Reports::PurchasingSummary::Query` |
| Customer Requests | `/reports/customer_requests` | `customer_requests.access` | `Reports::CustomerRequests::Query` |

Hub groups: Sales, Cash/Register, Taxes, Inventory, Buybacks, Customers, Stored Value, Purchasing.

---

## 4. Legacy redirects

| Legacy | Canonical |
| ------ | --------- |
| `/pos/reports` | `/reports` |
| `/pos/reports/register_summary` | `/reports/register_summary` |
| `/pos/reports/drawer` | `/reports/cash_drawer` |
| `/pos/reports/summary` | `/reports/sales_summary` |
| `/pos/reports/sales` | `/reports/sales` |
| `/pos/reports/returns` | `/reports/returns` |
| `/pos/reports/operational_margin` | `/reports/operational_margin` |
| `/buybacks/reports` | `/reports/buyback_summary` |
| `/customers/stored_value_reports` | `/reports/stored_value` |
| `/reports/shells/reconciliation` | `/reports/tax_collected` |
| `/reports/shells/queue` | `/reports/customer_requests` |

Query params preserved on redirect.

---

## 5. Acceptance criteria

Phase 9b complete when all reports in §3 use the report view contract, legacy URLs redirect, hub lists permitted reports only, query logic is tested, and views contain no complex business math.
