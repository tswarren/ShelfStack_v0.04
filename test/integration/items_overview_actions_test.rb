# frozen_string_literal: true

require "test_helper"

class ItemsOverviewActionsTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "overview_actions", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.view")
    grant_permission!(@user, "demand.access", store: @store)
    grant_permission!(@user, "demand.create", store: @store)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "overview_actions", password: "Password123!" }
    @product = create_legacy_catalog_linked_product!
    @variant = create_product_variant!(product: @product)
  end

  test "overview mounts variant operations drawer and details button" do
    get items_item_path(product_id: @product.id, tab: "overview")

    assert_response :success
    assert_select "#item-variant-ops-drawer"
    assert_select "#variant-availability button.ss-btn-secondary.ss-btn--small", text: "Details"
    assert_select "[data-controller*='item-variant-ops-drawer']"
  end

  test "overview shows request menu when demand access granted" do
    get items_item_path(product_id: @product.id, tab: "overview")

    assert_response :success
    assert_select ".ss-item-request-dropdown summary", text: "Request"
    assert_select ".ss-item-request-dropdown button.ss-dropdown-menu__item", minimum: 1
  end
end
