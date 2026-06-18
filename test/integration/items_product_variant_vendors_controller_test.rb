# frozen_string_literal: true

require "test_helper"

class ItemsProductVariantVendorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "items.access", store: @store)
    login_user!(@user, workstation: @workstation)

    @variant = create_product_variant!
    @vendor = create_vendor!
  end

  test "create variant vendor from items and return to display tab" do
    post items_product_variant_product_variant_vendors_path(@variant), params: {
      product_variant_vendor: {
        vendor_id: @vendor.id,
        vendor_item_number: "ITEMS-VV-1",
        supplier_discount_bps: 3500,
        returnability_status: "returnable",
        preferred: true,
        active: true
      }
    }

    variant_vendor = ProductVariantVendor.order(:id).last
    assert_response :redirect
    assert_includes response.location, "tab=item_setup"
    assert_includes response.location, "#vendor-sourcing"
    assert_includes response.location, "variant_id=#{@variant.id}"
    assert_equal "ITEMS-VV-1", variant_vendor.vendor_item_number
    assert AuditEvent.exists?(event_name: "product_variant_vendor.created", auditable: variant_vendor)
  end

  test "create variant vendor returns to from tbo when requested" do
    post items_product_variant_product_variant_vendors_path(@variant), params: {
      return_to: "from_tbo",
      from_tbo_vendor_id: @vendor.id,
      from_tbo_view: "vendor",
      product_variant_vendor: {
        vendor_id: @vendor.id,
        vendor_item_number: "FROM-TBO-1",
        supplier_discount_bps: 3500,
        returnability_status: "returnable",
        preferred: true,
        active: true
      }
    }

    assert_response :redirect
    assert_includes response.location, "/orders/purchase_orders/from_tbo"
    assert_includes response.location, "vendor_id=#{@vendor.id}"
  end

  test "new variant vendor form requires setup permission" do
    delete logout_path
    user = create_user!(username: "novendoruser")
    grant_permission!(user, "items.access", store: @store)
    login_user!(user, workstation: @workstation)

    get new_items_product_variant_product_variant_vendor_path(@variant)

    assert_redirected_to root_path
    assert_equal "You are not authorized to perform that action.", flash[:alert]
  end
end
