# frozen_string_literal: true

require "test_helper"

class Purchasing::PurchaseOrderDocumentHubTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @vendor = create_vendor!
    @user = create_user!
    @variant = create_product_variant!
    @purchase_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 4, quantity_received: 2) ]
    )
  end

  test "summarizes receive progress" do
    hub = Purchasing::PurchaseOrderDocumentHub.call(@purchase_order)

    assert_equal 4, hub.receive_progress.ordered
    assert_equal 2, hub.receive_progress.received
    assert_equal 2, hub.receive_progress.open
  end

  test "aggregates receipt summaries and discrepancies" do
    receipt = create_receipt!(
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
          unit_cost_cents: 800
        }
      ]
    )
    receipt_line = receipt.receipt_lines.first
    ReceivingDiscrepancy.create!(
      receipt_line: receipt_line,
      discrepancy_type: "short",
      quantity_delta: -1
    )

    hub = Purchasing::PurchaseOrderDocumentHub.call(@purchase_order.reload)

    assert_equal 1, hub.receipts.size
    assert_equal receipt.id, hub.receipts.first.receipt.id
    assert_equal 1, hub.receipts.first.accepted_quantity
    assert_equal 1, hub.discrepancies.size
    assert_equal "short", hub.discrepancies.first.discrepancy_type
    assert_equal 1, hub.line_activity.first.receipt_lines.size
  end
end
