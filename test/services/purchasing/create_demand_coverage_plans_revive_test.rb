# frozen_string_literal: true

require "test_helper"

class PurchasingCreateDemandCoveragePlansReviveTest < ActiveSupport::TestCase
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
    @line_plans = Purchasing::DemandCoveragePlanner.call(
      demand_lines: [ @demand ],
      vendor: @vendor,
      store: @store
    ).line_plans
  end

  test "revives released plan with same idempotency key" do
    Purchasing::ReleaseDemandCoveragePlan.call!(
      purchase_order: @purchase_order,
      actor: @user,
      reason: "Replacing coverage"
    )

    assert_no_difference -> { PurchaseOrderLineDemandPlan.count } do
      Purchasing::CreateDemandCoveragePlans.call!(
        purchase_order: @purchase_order,
        actor: @user,
        line_plans: @line_plans
      )
    end

    plan = @purchase_order.purchase_order_line_demand_plans.active_plans.first
    assert_equal "planned", plan.status
    assert_equal 2, plan.quantity_planned
  end
end
