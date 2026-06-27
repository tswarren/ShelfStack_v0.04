# frozen_string_literal: true

require "test_helper"

class ItemsSetupModalsIntegrationTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_permission!(@user, "items.access", store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    grant_permission!(@user, "items.catalog_items.update", store: @store)
    grant_permission!(@user, "items.product_variants.update", store: @store)
    grant_permission!(@user, "setup.product_vendors.create", store: @store)
    grant_permission!(@user, "setup.product_vendors.update", store: @store)
    login_user!(@user, workstation: @workstation)
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1299)
    @product = @variant.product
    @catalog_item = @product.catalog_item
    @vendor = create_vendor!
  end

  test "item setup tab renders setup modals" do
    get items_item_path(product_id: @product.id, tab: "item_setup")

    assert_response :success
    assert_includes response.body, 'id="item-identifier-modal"'
    assert_includes response.body, 'id="item-price-modal"'
    assert_includes response.body, "Quick add identifier"
    assert_includes response.body, "Quick edit price"
  end

  test "identifier quick create refreshes catalog section and closes modal" do
    post items_setup_modals_identifiers_path(catalog_item_id: @catalog_item.id),
         params: {
           identifier_type: "upc",
           identifier_value: "012345678905",
           primary: "0"
         },
         as: :turbo_stream

    assert_response :success
    assert_includes response.body, 'target="catalog-setup-section"'
    assert_includes response.body, 'target="toast_region"'
    assert_includes response.body, 'target="modal_close_triggers"'
    assert_includes response.body, "012345678905"
  end

  test "price quick update refreshes selling section" do
    patch items_setup_modals_variant_price_path(@variant),
          params: { selling_price_cents: 1599 },
          as: :turbo_stream

    assert_response :success
    assert_includes response.body, 'target="selling-setup-section"'
    assert_equal 1599, @variant.reload.selling_price_cents
  end

  test "identifier validation error keeps modal body replaceable" do
    post items_setup_modals_identifiers_path(catalog_item_id: @catalog_item.id),
         params: { identifier_type: "isbn13", identifier_value: "", primary: "0" },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, 'target="item-identifier-modal-body"'
  end

  test "classification tax preview returns derived tax category" do
    get items_setup_modals_classification_tax_preview_path(
      variant_id: @variant.id,
      sub_department_id: @variant.sub_department_id
    )

    assert_response :success
    assert_includes response.body, "classification-tax-preview-frame"
  end
end
