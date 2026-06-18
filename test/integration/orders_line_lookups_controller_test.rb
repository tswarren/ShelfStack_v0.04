# frozen_string_literal: true

require "test_helper"

class OrdersLineLookupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_permission!(@user, "orders.access", store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @variant.update!(sku: "LOOKUP-SKU-1")
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "HTTP-VEND-1",
      active: true
    )
  end

  test "line lookup returns enriched json" do
    get orders_line_lookup_path, params: { q: "HTTP-VEND-1", vendor_id: @vendor.id, context: "order" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "found", body["status"]
    assert_equal "HTTP-VEND-1", body["matches"].first["vendor_item_number"]
    assert body["matches"].first["sourcing_record_present"]
  end
end
