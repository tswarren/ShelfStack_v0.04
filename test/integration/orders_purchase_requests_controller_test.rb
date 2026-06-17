# frozen_string_literal: true

require "test_helper"

class OrdersPurchaseRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @purchase_request = PurchaseRequest.create!(store: @store, status: "open", notes: "Need stock")
    @request_line = @purchase_request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 4,
      request_reason: "tbo",
      status: "open"
    )
  end

  test "show includes build purchase order link when buildable" do
    get orders_purchase_request_path(@purchase_request)

    assert_response :success
    assert_match "Build Purchase Order", response.body
  end

  test "build purchase order form lists buildable lines" do
    get build_purchase_order_orders_purchase_request_path(@purchase_request)

    assert_response :success
    assert_match @variant.sku, response.body
    assert_match "Need stock", response.body
  end

  test "create purchase order builds draft po and marks request lines added_to_po" do
    post create_purchase_order_orders_purchase_request_path(@purchase_request), params: {
      vendor_id: @vendor.id,
      notes: "From TBO"
    }

    purchase_order = PurchaseOrder.order(:id).last
    assert_redirected_to orders_purchase_order_path(purchase_order)
    assert_equal "draft", purchase_order.status
    assert_equal @vendor.id, purchase_order.vendor_id
    assert_equal "From TBO", purchase_order.notes
    assert_equal 4, purchase_order.purchase_order_lines.first.quantity_ordered
    assert_equal "added_to_po", @request_line.reload.status
    assert_equal "added_to_po", @purchase_request.reload.status
  end

  test "create purchase order requires vendor" do
    post create_purchase_order_orders_purchase_request_path(@purchase_request), params: { vendor_id: "" }

    assert_redirected_to build_purchase_order_orders_purchase_request_path(@purchase_request)
    assert_equal "open", @request_line.reload.status
  end
end
