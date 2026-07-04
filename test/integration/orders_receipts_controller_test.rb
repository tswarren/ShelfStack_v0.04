# frozen_string_literal: true

require "test_helper"

class OrdersReceiptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @receipt = Receipt.create!(store: @store, vendor: @vendor, receipt_type: "direct", status: "draft")
    @line = @receipt.receipt_lines.create!(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 5,
      quantity_accepted: 5,
      quantity_rejected: 0
    )
  end

  test "update lowers accepted when received decreases" do
    patch orders_receipt_path(@receipt), params: {
      receipt: {
        vendor_id: @vendor.id,
        receipt_type: "direct",
        receipt_lines_attributes: {
          "0" => {
            id: @line.id,
            product_variant_id: @variant.id,
            quantity_expected: 0,
            quantity_received: 3,
            quantity_accepted: 5,
            quantity_rejected: 0
          }
        }
      }
    }

    assert_redirected_to orders_receipt_path(@receipt)
    assert_equal 3, @line.reload.quantity_accepted
    assert_equal 3, @line.quantity_received
  end

  test "update ignores blank added line rows" do
    patch orders_receipt_path(@receipt), params: {
      receipt: {
        vendor_id: @vendor.id,
        receipt_type: "direct",
        receipt_lines_attributes: {
          "0" => {
            id: @line.id,
            product_variant_id: @variant.id,
            quantity_expected: 0,
            quantity_received: 8,
            quantity_accepted: 0,
            quantity_rejected: 0
          },
          "1" => {
            product_variant_id: "",
            quantity_expected: 0,
            quantity_received: 0,
            quantity_accepted: 0,
            quantity_rejected: 0
          }
        }
      }
    }

    assert_redirected_to orders_receipt_path(@receipt)
    assert_equal 8, @line.reload.quantity_received
    assert_equal 1, @receipt.receipt_lines.count
  end

  test "update applies exception quantity and reason" do
    patch orders_receipt_path(@receipt), params: {
      receipt: {
        vendor_id: @vendor.id,
        receipt_type: "direct",
        receipt_lines_attributes: {
          "0" => {
            id: @line.id,
            product_variant_id: @variant.id,
            quantity_expected: 0,
            quantity_received: 10,
            quantity_accepted: 0,
            quantity_rejected: 2,
            exception_reason: "damaged"
          }
        }
      }
    }

    assert_redirected_to orders_receipt_path(@receipt)
    @line.reload
    assert_equal 8, @line.quantity_accepted
    assert_equal 2, @line.quantity_rejected
    assert_equal "damaged", @line.exception_reason
  end

  test "vendor shipment receipt edit renders match workpad when line has accepted quantity" do
    receipt = Receiving::CreateVendorShipmentReceipt.call!(
      store: @store,
      vendor: @vendor,
      attrs: {}
    )
    receipt.receipt_lines.create!(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 2,
      quantity_accepted: 2,
      quantity_rejected: 0
    )

    get edit_orders_receipt_path(receipt)

    assert_response :success
    assert_match "PO line matching", response.body
    assert_match "2 accepted", response.body
  end

  test "vendor shipment optional PO filter scopes match candidates without header PO" do
    purchase_order = PurchaseOrder.create!(
      store: @store,
      vendor: @vendor,
      status: "submitted",
      submitted_at: Time.current
    )
    purchase_order.purchase_order_lines.create!(
      product_variant: @variant,
      vendor: @vendor,
      quantity_ordered: 5,
      quantity_received: 0,
      status: "open"
    )
    other_vendor = create_vendor!(name: "Other Vendor")
    other_po = PurchaseOrder.create!(
      store: @store,
      vendor: other_vendor,
      status: "submitted",
      submitted_at: Time.current
    )

    post orders_receipts_path, params: {
      receiving_mode: "vendor_shipment",
      vendor_id: @vendor.id,
      match_filter_purchase_order_id: purchase_order.id
    }

    receipt = Receipt.order(:id).last
    assert_redirected_to edit_orders_receipt_path(receipt)
    assert_equal "vendor_shipment", receipt.receiving_mode
    assert_nil receipt.purchase_order_id
    assert_equal purchase_order.id, receipt.match_filter_purchase_order_id
    assert_not_equal other_po.id, receipt.match_filter_purchase_order_id
  end

  test "vendor shipment rejects PO filter from a different vendor" do
    other_vendor = create_vendor!(name: "Other Vendor")
    other_po = PurchaseOrder.create!(
      store: @store,
      vendor: other_vendor,
      status: "submitted",
      submitted_at: Time.current
    )

    assert_no_difference -> { Receipt.count } do
      post orders_receipts_path, params: {
        receiving_mode: "vendor_shipment",
        vendor_id: @vendor.id,
        match_filter_purchase_order_id: other_po.id
      }
    end

    assert_response :unprocessable_entity
    assert_match "must belong to the same vendor", response.body
  end

  test "vendor shipment rejects inactive vendor" do
    @vendor.update_columns(active: false)

    assert_no_difference -> { Receipt.count } do
      post orders_receipts_path, params: {
        receiving_mode: "vendor_shipment",
        vendor_id: @vendor.id
      }
    end

    assert_response :unprocessable_entity
    assert_match "Vendor not found", response.body
  end
end
