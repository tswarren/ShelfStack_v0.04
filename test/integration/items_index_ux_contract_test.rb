# frozen_string_literal: true

require "test_helper"

class ItemsIndexUxContractTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "items_ux_user", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.view")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "items_ux_user", password: "Password123!" }
    @item = create_catalog_item!(title: "Items UX Contract Book")
    create_product!(catalog_item: @item)
  end

  test "items index uses page header toolbar and filter actions" do
    get items_root_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Items"
    assert_select ".ss-page-description", text: /Search and browse catalog items/
    assert_select ".ss-page-actions .ss-btn-primary", text: "Add Product"
    assert_select ".ss-items-index-filters .ss-btn-primary", text: "Apply filters"
    assert_select ".ss-items-index-filters .ss-btn-tertiary", text: "Clear filters"
    assert_select ".ss-table"
  end

  test "items index empty search shows empty state with clear filters action" do
    get items_root_path, params: { q: "no-such-item-xyz" }

    assert_response :success
    assert_select ".ss-empty-state__title", text: "No items matched your search and filters"
    assert_select ".ss-empty-state__actions .ss-btn-tertiary", text: "Clear filters"
  end
end
