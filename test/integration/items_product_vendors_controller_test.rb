# frozen_string_literal: true

require "test_helper"

class ItemsProductVendorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "items.access", store: @store)
    login_user!(@user, workstation: @workstation)

    @product = create_product!
    @vendor = create_vendor!
  end

  test "create product vendor from items and return to vendor sourcing section" do
    post items_product_product_vendors_path(@product), params: {
      product_vendor: {
        vendor_id: @vendor.id,
        vendor_item_number: "ITEMS-PV-1",
        supplier_discount_bps: 3500,
        returnability_status: "returnable",
        preferred: true,
        active: true
      }
    }

    product_vendor = ProductVendor.order(:id).last
    assert_response :redirect
    assert_includes response.location, "tab=item_setup"
    assert_includes response.location, "#vendor-sourcing"
    assert_equal "ITEMS-PV-1", product_vendor.vendor_item_number
    assert AuditEvent.exists?(event_name: "product_vendor.created", auditable: product_vendor)
  end

  test "new product vendor form requires setup permission" do
    delete logout_path
    user = create_user!(username: "noproductvendoruser")
    grant_permission!(user, "items.access", store: @store)
    login_user!(user, workstation: @workstation)

    get new_items_product_product_vendor_path(@product)

    assert_redirected_to root_path
    assert_equal "You are not authorized to perform that action.", flash[:alert]
  end
end
