# frozen_string_literal: true

require "test_helper"

class InventoryReservationsConvertIncomingToOnHandTest < ActiveSupport::TestCase
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
      lines: [ { request_type: "special_order", requested_quantity: 3 } ]
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
          quantity_ordered: 3,
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
      quantity: 3,
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
      quantity_expected: 3,
      quantity_received: 1,
      quantity_accepted: 1,
      quantity_rejected: 0,
      unit_cost_cents: 1000
    )
  end

  test "partial conversion splits incoming reserve and keeps reserved balance aligned" do
    converted = InventoryReservations::ConvertIncomingToOnHand.call!(
      reservation: @incoming,
      receipt_line: @receipt_line,
      quantity: 1,
      converted_by_user: @user
    )

    @incoming.reload
    assert_equal "incoming_reserve", @incoming.reservation_type
    assert_equal "active", @incoming.status
    assert_equal 2, @incoming.quantity_reserved

    assert_equal "special_order_reserve", converted.reservation_type
    assert_equal "ready", converted.status
    assert_equal 1, converted.quantity_reserved

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 1, balance.quantity_reserved
    assert_equal 4, balance.quantity_available

    result = Inventory::BalanceIntegrityCheck.call(actor: @user)
    assert result.passed, "Expected integrity check to pass: #{result.mismatches.inspect}"
  end

  test "full conversion retypes incoming reserve without splitting" do
    InventoryReservations::ConvertIncomingToOnHand.call!(
      reservation: @incoming,
      receipt_line: @receipt_line,
      quantity: 3,
      converted_by_user: @user
    )

    @incoming.reload
    assert_equal "special_order_reserve", @incoming.reservation_type
    assert_equal "ready", @incoming.status
    assert_equal 3, @incoming.quantity_reserved
    assert_equal 1, InventoryReservation.where(special_order: @special_order).count

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 3, balance.quantity_reserved

    result = Inventory::BalanceIntegrityCheck.call(actor: @user)
    assert result.passed
  end

  test "rejects receipt line variant mismatch" do
    wrong_variant = ProductVariant.create!(
      product: @variant.product,
      sku: "MISMATCH-#{SecureRandom.hex(4)}",
      name: "Mismatch copy",
      sub_department: @variant.sub_department,
      condition: @variant.condition,
      inventory_behavior: "standard_physical",
      active: true,
      selling_price_cents: 1000
    )
    @receipt_line.update_column(:product_variant_id, wrong_variant.id)

    error = assert_raises(InventoryReservations::ConvertIncomingToOnHand::ConvertError) do
      InventoryReservations::ConvertIncomingToOnHand.call!(
        reservation: @incoming,
        receipt_line: @receipt_line,
        quantity: 1,
        converted_by_user: @user
      )
    end

    assert_match(/variant mismatch/i, error.message)
  end
end
