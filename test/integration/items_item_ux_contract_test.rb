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
    assert_select "main.ss-item-main", count: 0
    assert_select "section.ss-item-main[aria-label='Item overview']"
    assert_select ".ss-item-tabs a.active", text: "Overview"
    assert_select ".ss-item-hero + .ss-item-tabs"
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

  test "operations tab variant table and drawer use contract buttons" do
    grant_permission!(@user, "demand.access", store: @store)

    get item_path(tab: "operations")

    assert_response :success
    assert_select "button.ss-btn-secondary.ss-btn--small", text: "Details"
    assert_select "#item-variant-ops-drawer"
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Submit"
    assert_select "footer.ss-form-actions button.ss-btn-tertiary", text: "Cancel"
  end

  test "item setup display section uses contract vendor action buttons" do
    vendor = create_vendor!(name: "Display Vendor")
    ProductVendor.create!(product: @product, vendor: vendor, active: true)
    grant_permission!(@user, "setup.product_vendors.create", store: @store)
    grant_permission!(@user, "setup.product_vendors.update", store: @store)

    get item_path(tab: "item_setup")

    assert_response :success
    assert_select "#vendor-sourcing button.ss-btn-secondary.ss-btn--small", text: "Quick add product vendor"
    assert_select "#vendor-sourcing a.ss-btn-secondary.ss-btn--small", text: "Add product vendor"
    assert_select "#vendor-sourcing button.ss-btn-link", text: "Quick edit"
  end
end
