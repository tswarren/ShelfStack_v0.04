# frozen_string_literal: true

require "test_helper"

class PurchasingDemandCoveragePlannerTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(product: @variant.product, vendor: @vendor, active: true, preferred: true)
  end

  test "splits customer special order quantity from store replenishment" do
    customer_line = DemandLines::Create.call!(
      store: @store, actor: @user, capture_intent: "special_order",
      variant: @variant, customer: create_customer!, quantity: 2
    )
    store_line = DemandLines::Create.call!(
      store: @store, actor: @user, capture_intent: "manual_tbo",
      variant: @variant, quantity: 3
    )

    plan = Purchasing::DemandCoveragePlanner.call(
      demand_lines: [ customer_line, store_line ],
      vendor: @vendor,
      store: @store
    )

    customer_plan = plan.line_plans.find { |lp| lp.demand_line.id == customer_line.id }
    store_plan = plan.line_plans.find { |lp| lp.demand_line.id == store_line.id }

    assert_equal 2, customer_plan.customer_quantity
    assert_equal 0, customer_plan.store_quantity
    assert_equal 3, store_plan.store_quantity
    assert_equal 0, store_plan.customer_quantity
  end
end
