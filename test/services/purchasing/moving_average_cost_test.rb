# frozen_string_literal: true

require "test_helper"

class Purchasing::MovingAverageCostTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @balance = InventoryBalance.create!(
      store: @store,
      product_variant: @variant,
      quantity_on_hand: 0,
      quantity_available: 0
    )
  end

  test "sets mac on first receive" do
    Purchasing::MovingAverageCost.apply!(
      balance: @balance,
      prior_on_hand: 0,
      quantity_received: 10,
      unit_cost_cents: 800
    )

    assert_equal 800, @balance.moving_average_unit_cost_cents
  end

  test "weights average across receives" do
    @balance.update!(quantity_on_hand: 10, moving_average_unit_cost_cents: 800)

    Purchasing::MovingAverageCost.apply!(
      balance: @balance,
      prior_on_hand: 10,
      quantity_received: 10,
      unit_cost_cents: 1200
    )

    assert_equal 1000, @balance.moving_average_unit_cost_cents
  end

  test "no-op when unit cost is nil" do
    Purchasing::MovingAverageCost.apply!(
      balance: @balance,
      prior_on_hand: 0,
      quantity_received: 5,
      unit_cost_cents: nil
    )

    assert_nil @balance.moving_average_unit_cost_cents
  end
end
