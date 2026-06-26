# Phase 8.5-3a Test Plan

## Services

| Test file | Focus |
| --------- | ----- |
| `suggested_vendor_resolver_test.rb` | Full precedence + `source` |
| `order_eligibility_resolver_test.rb` | Block/warn matrix; discontinued; null condition; TBO context |
| `product_variants/orderability_defaults_test.rb` | Default table |
| `line_economics_calculator_test.rb` | Recalc, overrides, server authority |
| `operational_warning_builder_test.rb` | Severities, delegation |
| `submit_purchase_order_test.rb` | Submit blocked on ineligible lines; economics snapshots |
| `build_purchase_order_test.rb` | PO eligibility; no TBO+customer merge |
| `ingram_catalog_import/runner_test.rb` | Preferred vendor options |

## Controllers / integration

| Test file | Focus |
| --------- | ----- |
| `orders_purchase_orders_controller_test.rb` | Economics fields, eligibility on line add |
| `orders_purchase_requests_controller_test.rb` | Single-line create via service |

## Phase 7A regression

* `SpecialOrders::AttachToPurchaseOrderLine` with new PO economics fields
* `Purchasing::AllocateCustomerDemandToPoLine` still creates allocations
* `Receiving::AllocateCustomerDemandFromReceipt` FIFO unchanged

## Seeds / migration

* Migrations run cleanly on fresh and existing databases
* Backfill sets `orderable` and economics sources without null violations
