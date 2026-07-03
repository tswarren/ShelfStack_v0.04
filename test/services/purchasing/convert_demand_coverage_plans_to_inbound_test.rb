# frozen_string_literal: true

require "test_helper"

class PurchasingConvertDemandCoveragePlansToInboundTest < ActiveSupport::TestCase
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
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: @user)
    @purchase_order.reload
  end

  test "submit converts planned coverage to inbound allocation once" do
    inbound = DemandAllocation.active_allocations.inbound_kind.where(demand_line: @demand)
    assert_equal 1, inbound.count
    assert_equal 2, inbound.first.quantity_allocated

    plan = @purchase_order.purchase_order_line_demand_plans.first
    assert_equal "converted", plan.status
    assert_equal inbound.first.id, plan.converted_to_demand_allocation_id
  end

  test "retry conversion is idempotent" do
    assert_no_difference -> { DemandAllocation.active_allocations.inbound_kind.count } do
      Purchasing::ConvertDemandCoveragePlansToInbound.call!(purchase_order: @purchase_order, actor: @user)
    end
  end
end
