# frozen_string_literal: true

require "test_helper"

class OrdersDocumentHubIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!
    @variant = create_product_variant!
    @purchase_request = PurchaseRequest.create!(store: @store, status: "open")
    @request_line = @purchase_request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 4,
      status: "open"
    )
    @purchase_order = Purchasing::BuildPurchaseOrder.call(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      purchase_request_lines: [ @request_line ]
    )
    @purchase_order.purchase_order_lines.first.update!(
      quantity_received: 2,
      unit_list_price_cents: 2000,
      unit_cost_cents: 1200,
      variant_name_snapshot: @variant.name,
      variant_sku_snapshot: @variant.sku
    )
    @receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { purchase_order: @purchase_order, receipt_type: "po_backed", status: "posted" },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @purchase_order.purchase_order_lines.first,
          quantity_expected: 2,
          quantity_received: 1,
          quantity_accepted: 1,
          quantity_rejected: 0,
          unit_cost_cents: 1200
        }
      ]
    )
    ReceivingDiscrepancy.create!(
      receipt_line: @receipt.receipt_lines.first,
      discrepancy_type: "short",
      quantity_delta: -1
    )
  end

  test "purchase order show renders document hub panels" do
    get orders_purchase_order_path(@purchase_order)

    assert_response :success
    assert_match "Receive Progress", response.body
    assert_match "Related Purchase Requests", response.body
    assert_match "Related Receipts", response.body
    assert_match "Receiving Discrepancies", response.body
    assert_match "Line Receipt Activity", response.body
    assert_match @variant.name, response.body
    assert_match "href=\"/items/item", response.body
  end

  test "receipt show renders document hub panels" do
    get orders_receipt_path(@receipt)

    assert_response :success
    assert_match "Receipt Totals", response.body
    assert_match "Purchase Order", response.body
    assert_match "PO Line Alignment", response.body
    assert_match "Receiving Discrepancies", response.body
    assert_match @variant.name, response.body
  end

  test "purchase request show renders document hub panels" do
    get orders_purchase_request_path(@purchase_request)

    assert_response :success
    assert_match "Request Summary", response.body
    assert_match "Related Purchase Orders", response.body
    assert_match @variant.name, response.body
    assert_match "PO ##{@purchase_order.id}", response.body
  end
end
