# frozen_string_literal: true

require "test_helper"

class SourcingEligibilityTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0048TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "special order demand with variant is eligible" do
    demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant)

    result = Sourcing::Eligibility.for_demand_line(demand)

    assert result.eligible
  end

  test "used_wanted demand is rejected" do
    used_condition = ProductCondition.find_by(condition_key: "used_good") ||
      create_product_condition!(condition_key: "used_good_sourcing", name: "Used Good", short_name: "Used",
                                new_condition: false, buyback_eligible: true)
    used_variant = create_product_variant!(
      product: @variant.product,
      condition: used_condition,
      inventory_behavior: "standard_physical",
      sku: "211#{SecureRandom.random_number(10**10).to_s.rjust(10, '0')}"
    )
    demand = create_open_demand_line!(
      store: @store,
      actor: @user,
      variant: used_variant,
      capture_intent: "used_wanted"
    )

    result = Sourcing::Eligibility.for_demand_line(demand)

    assert_not result.eligible
    assert_match(/used-wanted/i, result.reason)
  end

  test "rejects when active run exists" do
    demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant)
    Sourcing::StartRun.call!(demand_line: demand, actor: @user)

    result = Sourcing::Eligibility.for_demand_line(demand.reload)

    assert_not result.eligible
    assert_match(/active sourcing run/i, result.reason)
  end
end
