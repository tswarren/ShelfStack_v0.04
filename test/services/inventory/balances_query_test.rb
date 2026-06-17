# frozen_string_literal: true

require "test_helper"

class Inventory::BalancesQueryTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @sub_department = nil
    3.times do
      variant = create_product_variant!(sub_department: @sub_department, inventory_behavior: "standard_physical")
      @sub_department ||= variant.sub_department
      post_inventory_adjustment!(
        create_inventory_adjustment!(
          store: @store,
          lines: [ { product_variant: variant, quantity_delta: 1, line_number: 1 } ]
        ),
        user: @user
      )
    end
  end

  test "paginates balances" do
    result = Inventory::BalancesQuery.call(store: @store, page: 1, per_page: 2)
    assert_equal 2, result.balances.size
    assert_equal 3, result.total_count
    assert_equal 1, result.page
  end

  test "filters by search query" do
    target = InventoryBalance.for_store(@store).first.product_variant
    result = Inventory::BalancesQuery.call(store: @store, query: target.sku)
    assert_equal 1, result.total_count
  end

  test "filters zero stock" do
    balances = InventoryBalance.for_store(@store).to_a
    balances.first.update_column(:quantity_on_hand, 0)
    balances.second.update_column(:quantity_on_hand, -1)

    result = Inventory::BalancesQuery.call(store: @store, stock_filter: "zero")
    assert_equal 2, result.total_count
  end

  test "filters low stock" do
    balances = InventoryBalance.for_store(@store).to_a
    balances[0].update_column(:quantity_on_hand, 3)
    balances[1].update_column(:quantity_on_hand, 5)
    balances[2].update_column(:quantity_on_hand, 10)

    result = Inventory::BalancesQuery.call(store: @store, stock_filter: "low")
    assert_equal 2, result.total_count
  end
end
