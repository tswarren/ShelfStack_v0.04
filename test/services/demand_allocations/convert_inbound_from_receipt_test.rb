# frozen_string_literal: true

require "test_helper"

class DemandAllocationsConvertInboundFromReceiptTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase5TestHelper
  include V0047TestHelper
  include V0048TestHelper

  setup do
    seed_v0047_permissions!
    grant_v0047_allocation_permissions!(@user = create_user!)
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)
    @po_line = @order.purchase_order_lines.first
    @demand_a = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 3)
    @demand_b = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 3)
    @inbound_a = DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_a, purchase_order_line: @po_line, actor: @user, quantity: 2
    )
    @inbound_b = DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_b, purchase_order_line: @po_line, actor: @user, quantity: 1
    )
    @receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { purchase_order: @order, receipt_type: "po_backed" },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @po_line,
          line_number: 1,
          quantity_expected: 5,
          quantity_received: 2,
          quantity_accepted: 2,
          quantity_rejected: 0,
          unit_cost_cents: 800
        }
      ]
    )
  end

  test "converts inbound allocations FIFO up to accepted quantity" do
    DemandAllocations::ConvertInboundFromReceipt.call!(receipt: @receipt, actor: @user)

    assert_equal "converted", @inbound_a.reload.status
    assert_equal "active", @inbound_b.reload.status
    on_hand_rows = DemandAllocation.on_hand_kind.where(conversion_receipt_line_id: @receipt.receipt_lines.first.id)
    assert_equal 2, on_hand_rows.sum(:quantity_allocated)
    assert_equal 2, on_hand_rows.find_by(converted_from_allocation_id: @inbound_a.id).quantity_allocated
  end

  test "partial conversion within one inbound allocation creates remainder inbound row" do
    [ @inbound_a, @inbound_b ].each do |allocation|
      allocation.update!(
        status: "released",
        released_at: Time.current,
        released_by_user: @user,
        release_reason: "test_setup"
      )
    end
    single = DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_b, purchase_order_line: @po_line, actor: @user, quantity: 3
    )

    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { purchase_order: @order, receipt_type: "po_backed" },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @po_line,
          line_number: 1,
          quantity_expected: 1,
          quantity_received: 1,
          quantity_accepted: 1,
          quantity_rejected: 0,
          unit_cost_cents: 800
        }
      ]
    )

    DemandAllocations::ConvertInboundFromReceipt.call!(receipt: receipt, actor: @user)

    assert_equal "converted", single.reload.status
    on_hand = DemandAllocation.on_hand_kind.find_by(conversion_receipt_line_id: receipt.receipt_lines.first.id)
    assert_equal 1, on_hand.quantity_allocated
    remainder = DemandAllocation.active_allocations.inbound_kind.find_by(converted_from_allocation_id: single.id)
    assert_equal 2, remainder.quantity_allocated
  end

  test "idempotent per receipt line" do
    DemandAllocations::ConvertInboundFromReceipt.call!(receipt: @receipt, actor: @user)
    assert_no_difference -> { DemandAllocation.on_hand_kind.where(conversion_receipt_line_id: @receipt.receipt_lines.first.id).count } do
      DemandAllocations::ConvertInboundFromReceipt.call!(receipt: @receipt, actor: @user)
    end
  end

  test "excludes vendor_backorder allocations" do
    seed_v0048_permissions!
    run = Sourcing::StartRun.call!(demand_line: @demand_a, actor: @user)
    attempt = Sourcing::CreateAttempt.call!(sourcing_run: run, actor: @user, vendor: @vendor, quantity: 1)
    Sourcing::SubmitAttempt.call!(sourcing_attempt: attempt, actor: @user)
    backorder = DemandAllocations::AllocateVendorBackorder.call!(
      demand_line: @demand_a,
      actor: @user,
      quantity: 1,
      sourcing_attempt: attempt,
      vendor_response: nil
    )

    DemandAllocations::ConvertInboundFromReceipt.call!(receipt: @receipt, actor: @user)

    assert_equal "active", backorder.reload.status
    assert_equal "vendor_backorder", backorder.allocation_kind
  end
end
