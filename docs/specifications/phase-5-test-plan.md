# Phase 5 Test Plan

Normative behavior: [phase-5-purchasing-and-receiving-spec.md](phase-5-purchasing-and-receiving-spec.md)

## Categories

| Category | Focus |
| --- | --- |
| Model tests | Sourcing, TBO, PO, receipt, RTV validations |
| Service tests | ReturnabilityResolver, VendorCostCalculator, PostReceipt, MovingAverageCost, PostReturnToVendor |
| Authorization | orders.* permissions, store scoping |
| Integration | End-to-end PO → receive → balance; RTV → negative balance |
| Audit | Lifecycle events |
| Seeds | Idempotent Phase 5 permissions and sourcing |

## Key scenarios

1. Returnability precedence across three levels
2. PO submit snapshots immutable fields
3. Receipt posts only accepted qty; updates MAC
4. PO-backed receipt updates PO line status
5. Direct receiving without PO
6. RTV blocked for non_returnable
7. Vendor column removal; forms updated
8. TBO does not change inventory

## Test layout

```text
test/models/product_vendor*
test/models/purchase_*
test/models/receipt*
test/models/return_to_vendor*
test/services/purchasing/*
test/integration/orders_*
test/integration/phase5_authorization_test.rb
test/support/phase5_test_helper.rb
```
