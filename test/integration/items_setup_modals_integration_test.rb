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
    grant_permission!(@user, "setup.product_variant_vendors.create", store: @store)
    grant_permission!(@user, "setup.product_variant_vendors.update", store: @store)
    login_user!(@user, workstation: @workstation)
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1299)
    @product = @variant.product
    @catalog_item = @product.catalog_item
    @vendor = create_vendor!(name: "Alpha Vendor")
    @vendor_b = create_vendor!(name: "Beta Vendor")
  end

  test "item setup tab renders setup modals" do
    get items_item_path(product_id: @product.id, tab: "item_setup")

    assert_response :success
    assert_includes response.body, 'id="item-identifier-modal"'
    assert_includes response.body, 'id="item-price-modal"'
    assert_includes response.body, "Quick add identifier"
    assert_includes response.body, "Quick edit price"
    assert_includes response.body, "data-modal-body-url"
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

  def second_variant
    @second_variant ||= ProductVariant.create!(
      product: @product,
      sub_department: @variant.sub_department,
      condition: @variant.condition,
      sku: "ALT#{SecureRandom.hex(3).upcase}",
      name: "Alternate variant",
      selling_price_cents: 1499,
      inventory_behavior: "standard_physical",
      orderable: true,
      active: true
    )
  end

  test "price edit form is server rendered for selected variant" do
    variant_b = second_variant
    get items_edit_setup_modals_variant_price_path(variant_b)

    assert_response :success
    assert_includes response.body, "item-price-modal-body"
    assert_includes response.body, 'value="1499"'
    assert_includes response.body, items_setup_modals_variant_price_path(variant_b)
  end

  test "price quick update refreshes selling section" do
    patch items_setup_modals_variant_price_path(@variant),
          params: { selling_price_cents: 1599 },
          as: :turbo_stream

    assert_response :success
    assert_includes response.body, 'target="selling-setup-section"'
    assert_equal 1599, @variant.reload.selling_price_cents
  end

  test "product vendor edit form is server rendered for persisted record" do
    product_vendor = ProductVendor.create!(
      product: @product,
      vendor: @vendor,
      vendor_item_number: "PV-100",
      supplier_discount_bps: 4000,
      preferred: true,
      active: true
    )

    get items_edit_setup_modals_product_vendor_path(product_vendor)

    assert_response :success
    assert_includes response.body, "Alpha Vendor"
    assert_includes response.body, 'value="PV-100"'
    assert_includes response.body, items_setup_modals_product_vendor_path(product_vendor)
    assert_not_includes response.body, 'name="product_vendor[vendor_id]"'
  end

  test "product vendor quick update changes sourcing fields without vendor select" do
    product_vendor = ProductVendor.create!(
      product: @product,
      vendor: @vendor,
      vendor_item_number: "OLD",
      supplier_discount_bps: 1000,
      preferred: false,
      active: true
    )

    patch items_setup_modals_product_vendor_path(product_vendor),
          params: {
            product_vendor: {
              vendor_item_number: "NEW-123",
              supplier_discount_bps: 2500,
              preferred: "1"
            }
          },
          as: :turbo_stream

    assert_response :success
    product_vendor.reload
    assert_equal "NEW-123", product_vendor.vendor_item_number
    assert_equal 2500, product_vendor.supplier_discount_bps
    assert product_vendor.preferred?
    assert_equal @vendor.id, product_vendor.vendor_id
  end

  test "new product vendor form uses create url after prior edit flow" do
    product_vendor = ProductVendor.create!(
      product: @product,
      vendor: @vendor,
      vendor_item_number: "OLD",
      active: true
    )
    get items_edit_setup_modals_product_vendor_path(product_vendor)
    assert_response :success

    get items_new_setup_modals_product_vendor_path(product_id: @product.id)

    assert_response :success
    assert_includes response.body, items_setup_modals_product_vendors_path
    assert_includes response.body, 'name="product_vendor[vendor_id]"'
    assert_not_includes response.body, "_method"
  end

  test "variant vendor edit form is server rendered for persisted override" do
    variant_b = second_variant
    variant_vendor = ProductVariantVendor.create!(
      product_variant: variant_b,
      vendor: @vendor_b,
      vendor_item_number: "VV-200",
      supplier_discount_bps: 3000,
      returnability_status: "returnable",
      preferred: true,
      active: true
    )

    get items_edit_setup_modals_variant_vendor_path(variant_vendor)

    assert_response :success
    assert_includes response.body, "Beta Vendor"
    assert_includes response.body, variant_b.sku
    assert_includes response.body, 'value="VV-200"'
    assert_includes response.body, items_setup_modals_variant_vendor_path(variant_vendor)
  end

  test "new variant vendor form targets requested variant" do
    variant_b = second_variant
    get items_new_setup_modals_variant_vendor_path(product_variant_id: variant_b.id)

    assert_response :success
    assert_includes response.body, variant_b.sku
    assert_includes response.body, 'name="product_variant_vendor[vendor_id]"'
    assert_includes response.body, 'value="' + variant_b.id.to_s + '"'
  end

  test "classification edit form uses selected variant for preview url" do
    variant_b = second_variant
    get items_edit_setup_modals_variant_classification_path(variant_b)

    assert_response :success
    assert_includes response.body, "classification-tax-preview"
    assert_includes response.body, "variant_id=#{variant_b.id}"
    assert_includes response.body, items_setup_modals_variant_classification_path(variant_b)
  end

  test "classification tax preview returns derived tax category for variant" do
    variant_b = second_variant
    get items_setup_modals_classification_tax_preview_path(
      variant_id: variant_b.id,
      sub_department_id: variant_b.sub_department_id
    )

    assert_response :success
    assert_includes response.body, "classification-tax-preview-frame"
  end

  test "identifier validation error keeps modal body replaceable" do
    post items_setup_modals_identifiers_path(catalog_item_id: @catalog_item.id),
         params: { identifier_type: "isbn13", identifier_value: "", primary: "0" },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, 'target="item-identifier-modal-body"'
    assert_includes response.body, 'turbo-frame id="item-identifier-modal-body"'
  end

  test "product vendor validation error preserves modal body turbo frame" do
    post items_setup_modals_product_vendors_path,
         params: {
           product_id: @product.id,
           product_vendor: {
             vendor_id: "",
             vendor_item_number: "BAD",
             supplier_discount_bps: 1000
           }
         },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, 'target="item-product-vendor-modal-body"'
    assert_includes response.body, 'turbo-frame id="item-product-vendor-modal-body"'
  end

  test "vendor modal shells render for update-only permissions" do
    delete logout_path
    update_user = create_user!(username: "vendor_editor", pin: "5678")
    grant_permission!(update_user, "items.access", store: @store)
    grant_permission!(update_user, "items.catalog_items.view", store: @store)
    grant_permission!(update_user, "setup.product_vendors.update", store: @store)
    grant_permission!(update_user, "setup.product_variant_vendors.update", store: @store)
    login_user!(update_user, workstation: @workstation)

    get items_item_path(product_id: @product.id, tab: "item_setup")

    assert_response :success
    assert_includes response.body, 'id="item-product-vendor-modal"'
    assert_includes response.body, 'id="item-variant-vendor-modal"'
    assert_not_includes response.body, 'id="item-price-modal"'
    assert_not_includes response.body, "Quick add product vendor"
  end
end
