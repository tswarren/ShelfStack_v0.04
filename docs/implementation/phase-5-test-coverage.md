# Phase 5 Test Coverage

Matrix mapping [phase-5-test-plan.md](../specifications/phase-5-test-plan.md) requirements to implemented tests.

## Models

| Area | Test file | Status |
| ---- | --------- | ------ |
| Returnability status validations | Implicit via service tests | Partial |
| Purchase request lifecycle | — | Gap |
| Purchase order line snapshots | — | Gap |
| Receipt line quantity rules | `post_receipt_test` (integration via service) | Partial |
| RTV returnability gate | — | Gap |

## Services

| Service | Test file | Status |
| ------- | --------- | ------ |
| `Purchasing::ReturnabilityResolver` | `test/services/purchasing/returnability_resolver_test.rb` | Covered |
| `Purchasing::VendorCostCalculator` | `test/services/purchasing/vendor_cost_calculator_test.rb` | Covered |
| `Purchasing::PostReceipt` | `test/services/purchasing/post_receipt_test.rb` | Covered |
| `Purchasing::MovingAverageCost` | Via `post_receipt_test` (balance MAC assertion) | Partial |
| `Purchasing::PostReturnToVendor` | — | Gap |
| `Purchasing::BuildPurchaseOrder` | `test/services/purchasing/build_purchase_order_test.rb` | Covered |
| `Purchasing::SubmitPurchaseOrder` | — | Gap |
| `Purchasing::SourcingLookup` | — | Gap |
| `Purchasing::UpdatePoLineQuantities` | — | Gap |

## Authorization

| Area | Test file | Status |
| ---- | --------- | ------ |
| Orders workspace gate | `test/integration/phase5_authorization_test.rb` | Covered |
| Per-resource permissions | `phase5_authorization_test` (purchase orders view) | Partial |

## Integration / System

| Flow | Test file | Status |
| ---- | --------- | ------ |
| Receive posts inventory + audit | `post_receipt_test` | Covered |
| TBO → PO → receive E2E | — | Gap |
| RTV reduces on-hand | — | Gap |
| PO submit snapshots | — | Gap |

## Seeds

| Area | Status |
| ---- | ------ |
| `phase5_permissions` idempotent | Via global seed in `test_helper` |
| `phase5_inventory` demo sourcing | Manual / dev seed only |

## Inventory integrity

Phase 4 rake task `shelfstack:inventory:check_integrity` remains the regression gate after receiving and RTV posts.

## Recommended follow-up tests

1. `post_return_to_vendor_test.rb` — non-returnable rejection and balance decrease
2. `submit_purchase_order_test.rb` — snapshot columns frozen at submit
3. `orders_purchase_orders_integration_test.rb` — draft → submit HTTP flow
4. Model tests for `ReceiptLine` accepted + rejected ≤ received validation
