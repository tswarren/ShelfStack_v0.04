# frozen_string_literal: true

require "test_helper"

class Items::ItemOverviewContractTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "overviewuser", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.view")
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "overviewuser", password: "Password123!" }
    @product = create_product!
    @variant = create_product_variant!(product: @product)
  end

  test "overview renders report drill-down contract regions" do
    get items_item_path(product_id: @product.id, tab: "overview")

    assert_response :success
    assert_select "#variant-matrix"
    assert_select ".ss-item-summary-cards"
    assert_select ".ss-item-hero"
  end

  test "overview renders warnings region when warnings present" do
    @variant.update!(selling_price_cents: 0)

    get items_item_path(product_id: @product.id, tab: "overview")

    assert_response :success
    assert_select "#warnings"
  end
end
