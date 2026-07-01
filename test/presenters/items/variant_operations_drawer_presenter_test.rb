# frozen_string_literal: true

require "test_helper"

class Items::VariantOperationsDrawerPresenterTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @product = create_product!
    @variant = create_product_variant!(product: @product, inventory_behavior: "standard_physical", selling_price_cents: 1299)
    @item = Items::ItemPresenter.from_product(@product)
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    grant_permission!(@user, "demand.access", store: @store)
    grant_permission!(@user, "demand.create", store: @store)
  end

  test "builds variant row and scoped operations tab for variant" do
    drawer = Items::VariantOperationsDrawerPresenter.for(
      item: @item,
      store: @store,
      user: @user,
      variant: @variant
    )

    assert_equal @variant, drawer.variant
    assert_equal @variant.id, drawer.variant_row.variant.id
    assert_equal @variant.id, drawer.operations_tab.highlight_variant.id
    assert drawer.demand_actions.any?
  end

  test "includes ordering warnings for new orderable variant" do
    drawer = Items::VariantOperationsDrawerPresenter.for(
      item: @item,
      store: @store,
      user: @user,
      variant: @variant
    )

    assert drawer.warnings.any? { |warning| warning.category == :ordering }
  end

  test "drawer recommended actions exclude legacy TBO and Order" do
    grant_permission!(@user, "orders.purchase_requests.create", store: @store)
    grant_permission!(@user, "orders.purchase_orders.create", store: @store)

    drawer = Items::VariantOperationsDrawerPresenter.for(
      item: @item,
      store: @store,
      user: @user,
      variant: @variant
    )

    labels = drawer.recommended_actions.map(&:label)
    refute_includes labels, "TBO"
    refute_includes labels, "Order"
  end
end
