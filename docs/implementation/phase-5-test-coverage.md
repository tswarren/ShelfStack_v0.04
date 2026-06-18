# Phase 5 Test Coverage

Matrix mapping [phase-5-test-plan.md](../specifications/phase-5-test-plan.md) requirements to implemented tests.

## Models

| Area | Test file | Status |
| ---- | --------- | ------ |
| Returnability status validations | `returnability_resolver_test`, `post_return_to_vendor_test` | Covered |
| Purchase request lifecycle (no inventory impact) | `test/models/purchase_request_test.rb` | Covered |
| Purchase order line immutability when submitted | `test/models/purchase_order_test.rb` | Covered |
| Purchase order receivable? | `test/models/purchase_order_receivable_test.rb` | Covered |
| Product vendor uniqueness / discount validation | `test/models/product_vendor_test.rb` | Covered |
| Receipt line quantity rules | `test/models/receipt_line_test.rb`, `post_receipt_test` | Covered |
| RTV returnability gate | `post_return_to_vendor_test` | Covered |

## Services

| Service | Test file | Status |
| ------- | --------- | ------ |
| `Purchasing::ReturnabilityResolver` | `test/services/purchasing/returnability_resolver_test.rb` | Covered |
| `Purchasing::VendorCostCalculator` | `test/services/purchasing/vendor_cost_calculator_test.rb` | Covered |
| `Purchasing::LinePriceDefaults` | `test/services/purchasing/line_price_defaults_test.rb` | Covered |
| `Purchasing::PostReceipt` | `test/services/purchasing/post_receipt_test.rb` | Covered |
| `Purchasing::MovingAverageCost` | `test/services/purchasing/moving_average_cost_test.rb` | Covered |
| `Purchasing::PostReturnToVendor` | `test/services/purchasing/post_return_to_vendor_test.rb` | Covered |
| `Purchasing::BuildPurchaseOrder` | `test/services/purchasing/build_purchase_order_test.rb` | Covered |
| `Purchasing::SubmitPurchaseOrder` | `test/services/purchasing/submit_purchase_order_test.rb` | Covered |
| `Purchasing::ClosePurchaseOrder` | `test/services/purchasing/close_purchase_order_test.rb` | Covered |
| `Purchasing::SourcingWarnings` | `test/services/purchasing/sourcing_warnings_test.rb` | Covered |
| `Purchasing::SourcingLookup` | `test/services/purchasing/sourcing_lookup_test.rb` | Covered |
| `Purchasing::UpdatePoLineQuantities` | `test/services/purchasing/update_po_line_quantities_test.rb` | Covered |
| `Purchasing::OrderQuantityLookup` | `test/services/purchasing/order_quantity_lookup_test.rb` | Covered |
| `Purchasing::LineLookup` | `test/services/purchasing/line_lookup_test.rb` | Covered |
| `Purchasing::LineLookupPresenter` | `test/services/purchasing/line_lookup_presenter_test.rb` | Covered |
| `Purchasing::BuildableTboLinesQuery` | `test/services/purchasing/buildable_tbo_lines_query_test.rb` | Covered |
| `Purchasing::TboQueueRowBuilder` | `test/services/purchasing/tbo_queue_row_builder_test.rb` | Covered |
| `Purchasing::SuggestedVendorResolver` | `test/services/purchasing/suggested_vendor_resolver_test.rb` | Covered |
| `Purchasing::BuildReceiptFromPurchaseOrder` | `test/services/purchasing/build_receipt_from_purchase_order_test.rb` | Covered |
| `Purchasing::PurchaseOrderSummary` | `test/services/purchasing/purchase_order_summary_test.rb` | Covered |
| `Purchasing::PurchaseOrderDocumentHub` | `test/services/purchasing/purchase_order_document_hub_test.rb` | Covered |
| `Purchasing::ReceiptDocumentHub` | `test/services/purchasing/receipt_document_hub_test.rb` | Covered |
| `Purchasing::PurchaseRequestDocumentHub` | `test/services/purchasing/purchase_request_document_hub_test.rb` | Covered |

## Authorization

| Area | Test file | Status |
| ---- | --------- | ------ |
| Orders workspace gate | `test/integration/phase5_authorization_test.rb` | Covered |
| Per-resource permissions (PO view, receipt post) | `phase5_authorization_test` | Covered |
| Store-scoped permission enforcement | `phase5_authorization_test` | Covered |

## Integration / System

| Flow | Test file | Status |
| ---- | --------- | ------ |
| Receive posts inventory + audit | `post_receipt_test` | Covered |
| Receiving discrepancy recording | `post_receipt_test` | Covered |
| TBO → PO → receive → RTV E2E | `test/integration/orders_purchasing_workflow_integration_test.rb` | Covered |
| RTV reduces on-hand | `post_return_to_vendor_test`, workflow integration | Covered |
| PO submit snapshots (HTTP) | `orders_purchasing_workflow_integration_test` | Covered |
| PO line removal on update | `test/integration/orders_purchase_orders_controller_test.rb` | Covered |
| PO close workflow (HTTP) | `orders_purchase_orders_controller_test` | Covered |
| PO receive → preloaded receipt (HTTP) | `orders_purchase_orders_controller_test` | Covered |
| Purchasing line lookup API | `test/integration/orders_line_lookups_controller_test.rb` | Covered |
| TBO build PO / from_tbo | `orders_purchase_requests_controller_test`, `orders_purchase_orders_controller_test` | Covered |
| Purchasing workbench UI | `test/integration/orders_purchasing_workbench_integration_test.rb` | Covered |
| Orders document hub show pages | `test/integration/orders_document_hub_integration_test.rb` | Covered |
| RTV inventory-aware workpad | `orders_returns_to_vendor_controller_test`, `orders_line_lookups_controller_test` | Covered |
| Receipt line exception_reason | `test/models/receipt_line_test.rb` | Covered |
| Receipt exception-first controller | `test/integration/orders_receipts_controller_test.rb` | Covered |
| TBO partial qty / suggested view / queue columns | `orders_purchase_orders_controller_test` | Covered |
| Items variant vendor return to from_tbo | `items_product_variant_vendors_controller_test` | Covered |

## Seeds

| Area | Test file | Status |
| ---- | --------- | ------ |
| `phase5_permissions` idempotent | Via global seed in `test_helper` | Covered |
| `phase5_inventory` demo sourcing | `test/models/phase5_inventory_seed_test.rb` | Covered |

## Inventory integrity

Phase 4 rake task `shelfstack:inventory:check_integrity` remains the regression gate after receiving and RTV posts.
