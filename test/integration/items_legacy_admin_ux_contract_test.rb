# frozen_string_literal: true

require "test_helper"

class ItemsLegacyAdminUxContractTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "items_legacy_ux", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_all_phase3_permissions!(@user)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "items_legacy_ux", password: "Password123!" }
    @product = create_legacy_catalog_linked_product!
    @variant = create_product_variant!(product: @product)
    @catalog_item = @product.catalog_item
  end

  test "products index uses page header table and status badges when rows exist" do
    get items_products_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Products"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
    assert_select ".ss-table"
    assert_select ".ss-status-badge.status-active", text: "Active"
    assert_select "a[href='#{items_product_path(@product)}']", text: "View"
  end

  test "products index shows empty state when no products exist" do
    ProductVariant.delete_all
    ProductIdentifier.delete_all
    ProductVendor.delete_all
    Product.delete_all

    get items_products_path

    assert_response :success
    assert_select ".ss-empty-state__title", text: "No products yet"
    assert_select ".ss-empty-state__actions .ss-btn-primary", text: "New"
  end

  test "product variants index uses page header and status badges" do
    get items_product_variants_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Product Variants"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
    assert_select ".ss-status-badge.status-active", text: "Active"
    assert_select "a[href='#{items_product_variant_path(@variant)}']", text: "View"
  end

  test "catalog item show separates lifecycle and danger zone actions" do
    get items_catalog_item_path(@catalog_item)

    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Catalog Items/
    assert_select ".ss-page-header h1", text: @catalog_item.title
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Inactivate"), :<, page_actions.index("Edit")
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select ".ss-page-actions .ss-btn-danger", count: 0
    assert_select "#catalog-item-danger-zone-heading", text: "Danger zone"
    assert_select ".ss-section-actions .ss-btn-danger", text: "Delete catalog item"
    assert_select "a.ss-btn-link", text: "Edit"
  end

  test "product show separates lifecycle and danger zone actions" do
    get items_product_path(@product)

    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Products/
    assert_select ".ss-page-header h1", text: @product.name
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Inactivate"), :<, page_actions.index("Edit")
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#product-danger-zone-heading", text: "Danger zone"
    assert_select ".ss-section-actions .ss-btn-danger", text: "Delete product"
  end

  test "product variant show separates lifecycle and danger zone actions" do
    get items_product_variant_path(@variant)

    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Item setup/
    assert_select ".ss-page-header h1", text: @variant.name
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Inactivate"), :<, page_actions.index("Edit")
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#product-variant-danger-zone-heading", text: "Danger zone"
    assert_select ".ss-section-actions .ss-btn-danger", text: "Delete variant"
  end

  test "legacy admin forms use primary submit and tertiary cancel" do
    get new_items_product_path
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Product"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"

    get edit_items_product_path(@product)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Update Product"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"

    get new_items_product_variant_path(product_id: @product.id)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Variant"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"

    get edit_items_product_variant_path(@variant)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Update Variant"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"

    identifier = @product.product_identifiers.first
    get edit_identifier_items_catalog_item_path(@catalog_item, identifier_id: identifier.id)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Save Identifier"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"
  end
end
