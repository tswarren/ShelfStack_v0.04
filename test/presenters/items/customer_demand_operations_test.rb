# frozen_string_literal: true

require "test_helper"

class ItemsCustomerDemandOperationsTest < ActiveSupport::TestCase
  include Phase7aTestHelper
  include V0047TestHelper

  setup do
    Seeds::V0046Permissions.seed!
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_permission!(@user, "demand.access", store: @store)
    grant_v0047_allocation_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 3, line_number: 1 } ]
      ),
      user: @user
    )
    @product = @variant.product
    @demand_line = create_hold_with_on_hand_allocation!(store: @store, actor: @user, variant: @variant, quantity: 1)
  end

  test "operations tab presenter includes customer demand metrics" do
    presenter = Items::ItemOperationsTabPresenter.new(
      item: Items::ItemPresenter.from_product(@product),
      store: @store,
      user: @user
    )

    assert presenter.customer_demand_visible?
    assert_operator presenter.metrics.find { |metric| metric[:label] == "Open demand" }[:value], :>=, 1
    assert_operator presenter.metrics.find { |metric| metric[:label] == "Active holds" }[:value], :>=, 1
  end
end
