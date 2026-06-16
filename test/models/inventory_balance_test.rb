# frozen_string_literal: true

require "test_helper"

class InventoryBalanceTest < ActiveSupport::TestCase
  setup do
    seed_phase4_reference_data!
    @store = create_store!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "unique balance per store and variant" do
    InventoryBalance.create!(
      store: @store,
      product_variant: @variant,
      quantity_on_hand: 1,
      quantity_available: 1,
      inventory_cost_value_cents: 0,
      inventory_retail_value_cents: 0
    )

    duplicate = InventoryBalance.new(
      store: @store,
      product_variant: @variant,
      quantity_on_hand: 2,
      quantity_available: 2,
      inventory_cost_value_cents: 0,
      inventory_retail_value_cents: 0
    )
    assert_not duplicate.valid?
  end
end
