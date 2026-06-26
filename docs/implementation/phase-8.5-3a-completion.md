# Phase 8.5-3a Completion — Ordering Readiness

**Branch:** `phase-8.5-3-order-readiness`  
**Status:** Complete (pending merge)

## Deliverables

### Schema
- `products.preferred_vendor_id`
- `product_variants.preferred_vendor_id`, `product_variants.orderable`
- PO line economics: expected retail/margin caches, `cost_source`, `price_source`, override flags, `line_note`, `source_snapshot`

### Services
- `ProductVariants::OrderabilityDefaults`
- Extended `Purchasing::SuggestedVendorResolver` with `source`
- `Purchasing::OrderEligibilityResolver` (`:purchase_order`, `:purchase_order_submit`, `:tbo`)
- `Purchasing::LineEconomicsCalculator`
- `Items::OperationalWarningBuilder`
- Submit gate in `Purchasing::SubmitPurchaseOrder`
- PO build eligibility + TBO/special-order merge guard in `Purchasing::BuildPurchaseOrder`

### UI
- Preferred vendor on product/variant forms
- Operations tab vendor source + operational warnings
- PO line economics fields (retail, margin preview in details)
- Ingram import preferred-vendor options

### 8.5-3b (same branch)
- `PurchaseRequests::CreateSingleLine`
- Single-line TBO create path
- TBO `from_tbo` PO eligibility column

### 8.5-3c (same branch)
- Receipt show projected vs actual allocation visibility

## Verification

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test test/services/purchasing/order_eligibility_resolver_test.rb
./dev/rails-docker bin/rails test test/services/purchasing/suggested_vendor_resolver_test.rb
./dev/rails-docker bin/rails test test/services/purchasing/line_economics_calculator_test.rb
./dev/rails-docker bin/rails test test/services/purchasing/submit_purchase_order_test.rb
./dev/rails-docker bin/rails test test/services/purchasing/build_purchase_order_test.rb
./dev/rails-docker bin/rails test test/services/special_orders/attach_to_purchase_order_line_test.rb
./dev/rails-docker bin/rails test test/services/receiving/allocate_customer_demand_from_receipt_test.rb
```

## Known gaps / deferred

- Discontinued manager override (submit block only)
- `preferred_vendor_id` on TBO lines (by design)
- Unified demand inbox / `PurchaseDemand`
