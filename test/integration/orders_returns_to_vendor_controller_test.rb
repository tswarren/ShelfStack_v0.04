# frozen_string_literal: true

require "test_helper"

class OrdersReturnsToVendorControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "RTV-VEND-1",
      returnability_status: "returnable",
      active: true
    )
    Current.store = @store
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 6, unit_cost_cents: 900)
  end

  test "new return form renders inventory-aware line table" do
    get new_orders_returns_to_vendor_path

    assert_response :success
    assert_match "ss-purchasing-table", response.body
    assert_match "Credit", response.body
    assert_match "On hand", response.body
    assert_match "Returnability", response.body
    assert_match "toggleDetails", response.body
    assert_match 'data-purchasing-line-row-context-value="rtv"', response.body
    assert_match "refresh-on-vendor-change-value", response.body
  end

  test "return to vendor show uses progressive disclosure layout" do
    rtv = create_return_to_vendor!(
      store: @store,
      vendor: @vendor,
      lines: [ { product_variant: @variant, quantity: 1, unit_cost_cents: 900, credit_amount_cents: 900 } ]
    )

    get orders_returns_to_vendor_path(rtv)

    assert_response :success
    assert_select ".ss-metric-strip"
    assert_select ".ss-document-layout"
    assert_match "Est. credit", response.body
    assert_match @variant.name, response.body
  end

  test "line lookup rtv context returns on-hand and returnability" do
    get orders_line_lookup_path, params: {
      q: @variant.sku,
      vendor_id: @vendor.id,
      context: "rtv"
    }

    assert_response :success
    body = JSON.parse(response.body)
    match = body["matches"].first
    assert_equal 6, match["quantity_on_hand"]
    assert_equal "returnable", match["returnability_status"]
  end
end
