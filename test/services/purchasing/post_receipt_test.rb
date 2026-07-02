# frozen_string_literal: true

require "test_helper"

class Purchasing::PostReceiptTest < ActiveSupport::TestCase
  include V0047TestHelper

  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    Current.store = @store
  end

  test "posts only accepted quantity and updates balance" do
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      lines: [
        {
          product_variant: @variant,
          line_number: 1,
          quantity_expected: 5,
          quantity_received: 5,
          quantity_accepted: 4,
          quantity_rejected: 1,
          unit_cost_cents: 800
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    assert_equal "posted", receipt.reload.status
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 4, balance.quantity_on_hand
    assert_equal 800, balance.moving_average_unit_cost_cents
    assert AuditEvent.exists?(event_name: "receipt.posted", auditable: receipt)
  end

  test "defaults accepted from received when posting" do
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      lines: [
        {
          product_variant: @variant,
          line_number: 1,
          quantity_expected: 0,
          quantity_received: 5,
          quantity_accepted: 0,
          quantity_rejected: 0,
          unit_cost_cents: 800
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 5, balance.quantity_on_hand
    assert_equal 5, receipt.receipt_lines.first.reload.quantity_accepted
  end

  test "rejects post when no accepted quantity remains" do
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      lines: [
        {
          product_variant: @variant,
          line_number: 1,
          quantity_expected: 0,
          quantity_received: 5,
          quantity_accepted: 0,
          quantity_rejected: 5,
          unit_cost_cents: 800
        }
      ]
    )

    error = assert_raises(Purchasing::PostReceipt::PostingError) do
      Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)
    end
    assert_match(/accepted quantity/i, error.message)
  end

  test "records discrepancy when received differs from expected" do
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      lines: [
        {
          product_variant: @variant,
          line_number: 1,
          quantity_expected: 5,
          quantity_received: 3,
          quantity_accepted: 3,
          quantity_rejected: 0,
          unit_cost_cents: 800
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    discrepancy = receipt.receipt_lines.first.receiving_discrepancies.first
    assert_equal "short", discrepancy.discrepancy_type
    assert_equal(-2, discrepancy.quantity_delta)
  end

  test "posts PO-backed receipt and converts v0.04 inbound allocations" do
    seed_v0047_permissions!
    grant_v0047_allocation_permissions!(@user)
    demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 2)
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 4) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)
    po_line = order.purchase_order_lines.first
    inbound = DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: demand_line, purchase_order_line: po_line, actor: @user, quantity: 2
    )
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { purchase_order: order, receipt_type: "po_backed" },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: po_line,
          line_number: 1,
          quantity_expected: 4,
          quantity_received: 2,
          quantity_accepted: 2,
          quantity_rejected: 0,
          unit_cost_cents: 800
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    assert_equal "posted", receipt.reload.status
    assert_equal "converted", inbound.reload.status
    on_hand = DemandAllocation.on_hand_kind.find_by(converted_from_allocation_id: inbound.id)
    assert_equal 2, on_hand.quantity_allocated
    assert_equal 2, po_line.reload.quantity_received
  end

  test "rolls back entire post when conversion fails" do
    seed_v0047_permissions!
    grant_v0047_allocation_permissions!(@user)
    demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 1)
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 3) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)
    po_line = order.purchase_order_lines.first
    DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: demand_line, purchase_order_line: po_line, actor: @user, quantity: 1
    )
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { purchase_order: order, receipt_type: "po_backed" },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: po_line,
          line_number: 1,
          quantity_expected: 3,
          quantity_received: 1,
          quantity_accepted: 1,
          quantity_rejected: 0,
          unit_cost_cents: 800
        }
      ]
    )
    before = inventory_snapshot(store: @store, variant: @variant)

    original_call = DemandAllocations::ConvertInboundFromReceipt.method(:call!)
    DemandAllocations::ConvertInboundFromReceipt.singleton_class.define_method(:call!) do |**|
      raise DemandAllocations::ConvertInboundFromReceipt::ConversionError, "boom"
    end

    begin
      assert_raises(DemandAllocations::ConvertInboundFromReceipt::ConversionError) do
        Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)
      end

      assert_equal "draft", receipt.reload.status
      assert_equal 0, po_line.reload.quantity_received
      after = inventory_snapshot(store: @store, variant: @variant)
      assert_inventory_unchanged_except_cache(before: before, after: after)
      assert DemandAllocation.on_hand_kind.where(conversion_receipt_line_id: receipt.receipt_lines.first.id).none?
    ensure
      DemandAllocations::ConvertInboundFromReceipt.singleton_class.define_method(:call!, original_call)
    end
  end
end
