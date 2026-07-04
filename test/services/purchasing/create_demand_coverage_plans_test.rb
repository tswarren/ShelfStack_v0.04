# frozen_string_literal: true

require "test_helper"

class PurchasingCreateDemandCoveragePlansTest < ActiveSupport::TestCase
  include Phase7aTestHelper
  include Phase5TestHelper
  include V0047TestHelper

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

  test "creates durable planned coverage on draft PO" do
    plans = @purchase_order.purchase_order_line_demand_plans.active_plans
    assert_equal 1, plans.count
    assert_equal 2, plans.first.quantity_planned
    assert_equal "customer_fulfillment", plans.first.coverage_kind
    assert_equal "inbound_to_store", plans.first.fulfillment_route
  end

  test "planned coverage does not create inbound allocation while draft" do
    assert_equal 0, DemandAllocation.active_allocations.inbound_kind.where(demand_line: @demand).count
  end

  test "idempotent create does not duplicate plans" do
    line_plans = Purchasing::DemandCoveragePlanner.call(
      demand_lines: [ @demand ],
      vendor: @vendor,
      store: @store
    ).line_plans

    assert_no_difference -> { PurchaseOrderLineDemandPlan.count } do
      Purchasing::CreateDemandCoveragePlans.call!(
        purchase_order: @purchase_order,
        actor: @user,
        line_plans: line_plans
      )
    end
  end
end
