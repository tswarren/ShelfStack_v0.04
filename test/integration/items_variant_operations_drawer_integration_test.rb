# frozen_string_literal: true

require "test_helper"

class ItemsVariantOperationsDrawerIntegrationTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase3TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_permission!(@user, "items.access", store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    grant_permission!(@user, "customer_requests.access", store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    login_user!(@user, workstation: @workstation)
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1299)
    @product = @variant.product
  end

  test "drawer endpoint renders turbo frame body for variant" do
    get items_variant_operations_drawer_path(product_variant_id: @variant.id)

    assert_response :success
    assert_includes response.body, 'id="variant-ops-drawer-frame"'
    assert_includes response.body, @variant.sku
    assert_includes response.body, "Variant summary"
  end

  test "operations tab includes variant ops drawer shell and details button" do
    get items_item_path(product_id: @product.id, tab: "operations")

    assert_response :success
    assert_includes response.body, 'id="item-variant-ops-drawer"'
    assert_includes response.body, "Details"
    assert_includes response.body, "item-variant-ops-drawer"
  end
end
