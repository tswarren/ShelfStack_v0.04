# frozen_string_literal: true

require "test_helper"

class PurchasingPurchaseOrderLineDemandBreakdownDraftTest < ActiveSupport::TestCase
  include Phase7aTestHelper
  include Phase5TestHelper

  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(product: @variant.product, vendor: @vendor, active: true, preferred: true)
    @demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 2
    )
    @purchase_order = Purchasing::BuildPurchaseOrderFromDemand.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      demand_line_ids: [ @demand.id ]
    )
  end

  test "draft breakdown shows planned customer coverage before inbound allocation" do
    breakdown = Purchasing::PurchaseOrderLineDemandBreakdown.for(@purchase_order).first

    assert_equal :planned, breakdown.coverage_mode
    assert_equal 2, breakdown.demand_allocated_quantity
    assert_equal 1, breakdown.plan_rows.size
    assert_equal "customer_fulfillment", breakdown.plan_rows.first.coverage_kind
    assert_empty breakdown.allocation_rows
    assert_equal 0, DemandAllocation.active_allocations.inbound_kind.count
  end
end
