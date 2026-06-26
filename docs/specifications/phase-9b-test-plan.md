# Phase 9b — Test Plan

Master spec: [phase-9b-operational-reports-spec.md](phase-9b-operational-reports-spec.md)

---

## Hub and infrastructure

| Test | Focus |
| ---- | ----- |
| `Reports::RegistryTest` | All reports registered; permission keys present |
| `Reports::IndexControllerTest` | Hub shows only permitted reports; nav visibility |
| Redirect tests | Legacy POS/buyback/SV URLs 302 to canonical paths with params |

---

## Per-report matrix

| Report | Service tests | Integration tests |
| ------ | ------------- | ----------------- |
| Register Summary | Session scope totals | Auth, filter bar, print regions |
| Sales Summary | Date/session scope, revenue totals | CSV export auth |
| Tax Collected | Exempt vs non-taxable, rate grouping | Contract regions |
| Discount Summary | Reason grouping, void exclusion | Contract regions |
| Operational Margin | Void excluded, COGS columns | Empty state |
| Buyback Summary | Completed-only, cash vs trade credit | Contract regions |
| Stored Value | Balance sum, activity date filter | Date filter UI |
| Inventory Value | Non-inventory exclusion | Enterprise section gated |
| Purchasing Summary | PO status counts, accepted qty | Contract regions |
| Customer Requests | Status filter, aging | Item drill-down links |

---

## Verification command

```bash
./dev/rails-docker bin/rails test \
  test/services/reports/ \
  test/integration/reports/
```
