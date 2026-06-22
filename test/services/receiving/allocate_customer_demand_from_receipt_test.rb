# frozen_string_literal: true

require "test_helper"

class ReceivingAllocateCustomerDemandFromReceiptTest < ActiveSupport::TestCase
  include Phase5TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 5)
    @customer = create_customer!
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "special_order", requested_quantity: 2 } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @special_order = SpecialOrders::CreateFromRequestLine.call!(line: @line, created_by_user: @user)
    SpecialOrders::Approve.call!(special_order: @special_order, approved_by_user: @user)
    @purchase_order = PurchaseOrder.create!(
      store: @store,
      vendor: @vendor,
      status: "draft",
      purchase_order_lines: [
        PurchaseOrderLine.new(
          line_number: 1,
          product_variant: @variant,
          vendor: @vendor,
          quantity_ordered: 2,
          quantity_received: 0,
          unit_cost_cents: 1000,
          variant_sku_snapshot: @variant.sku,
          variant_name_snapshot: @variant.name
        )
      ]
    )
    @po_line = @purchase_order.purchase_order_lines.first
    SpecialOrders::AttachToPurchaseOrderLine.call!(
      special_order: @special_order,
      purchase_order_line: @po_line,
      quantity: 2,
      attached_by_user: @user
    )
    @incoming = InventoryReservation.active_incoming.find_by!(special_order: @special_order)
    @receipt = Receipt.create!(
      store: @store,
      vendor: @vendor,
      purchase_order: @purchase_order,
      receipt_type: "po_backed",
      status: "draft"
    )
    @receipt_line = @receipt.receipt_lines.create!(
      line_number: 1,
      purchase_order_line: @po_line,
      product_variant: @variant,
      quantity_expected: 2,
      quantity_received: 1,
      quantity_accepted: 1,
      quantity_rejected: 0,
      unit_cost_cents: 1000
    )
  end

  test "creates receipt line allocation linked to converted reservation" do
    Receiving::AllocateCustomerDemandFromReceipt.call!(receipt: @receipt, posted_by_user: @user)

    allocation = ReceiptLineAllocation.find_by!(receipt_line: @receipt_line)
    converted = InventoryReservation.find_by!(receipt_line: @receipt_line, reservation_type: "special_order_reserve")

    assert_equal converted.id, allocation.inventory_reservation_id
    assert_equal 1, allocation.quantity_allocated
    assert_equal 1, @special_order.reload.quantity_ready
  end
end
