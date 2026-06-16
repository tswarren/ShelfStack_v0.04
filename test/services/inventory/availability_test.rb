# frozen_string_literal: true

require "test_helper"

class Inventory::AvailabilityTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @eligible = create_product_variant!(inventory_behavior: "standard_physical")
    @ineligible = create_product_variant!(
      sub_department: @eligible.sub_department,
      inventory_behavior: "non_inventory"
    )
    Current.store = @store
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @eligible, quantity_delta: 4, line_number: 1 } ]
      ),
      user: create_user!
    )
  end

  test "available returns nil for ineligible variant" do
    assert_nil Inventory::Availability.available(store: @store, variant: @ineligible)
  end

  test "product on hand sums eligible variants only" do
    product = @eligible.product
    total = Inventory::Availability.product_on_hand(store: @store, product: product)
    assert_equal 4, total
  end
end
