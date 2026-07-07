# frozen_string_literal: true

require "test_helper"

class ItemsItemUxContractTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "item_detail_ux", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.view")
    grant_permission!(@user, "items.products.update")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "item_detail_ux", password: "Password123!" }
    @product = create_legacy_catalog_linked_product!
    @variant = create_product_variant!(product: @product)
  end

  def item_path(**params)
    items_item_path({ product_id: @product.id }.merge(params))
  end

  test "overview keeps hero title and adds back link without duplicate page header" do
    get item_path(tab: "overview")

    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Back to Items/
    assert_select ".ss-item-hero h1.ss-item-title", text: @product.title
    assert_select ".ss-page-header", count: 0
    assert_select ".ss-item-tabs a.active", text: "Overview"
  end

  test "item setup tab uses page header and selling setup action buttons" do
    get item_path(tab: "item_setup")

    assert_response :success
    assert_select ".ss-page-header h1", text: @product.title
    assert_select ".ss-page-description", text: /Catalog metadata, selling setup/
    assert_select ".ss-catalog-actions .ss-btn-secondary", text: "New sellable SKUs"
    assert_select ".ss-catalog-actions .ss-btn-primary", text: "Edit product"
  end

  test "operations tab uses page header and empty state when no variants" do
    @variant.destroy!

    get item_path(tab: "operations")

    assert_response :success
    assert_select ".ss-page-header h1", text: @product.title
    assert_select ".ss-empty-state__title", text: "No variant operations yet"
  end

  test "activity tab uses page header" do
    get item_path(tab: "activity")

    assert_response :success
    assert_select ".ss-page-header h1", text: @product.title
    assert_select ".ss-page-description", text: /Inventory movements and audit history/
  end
end
