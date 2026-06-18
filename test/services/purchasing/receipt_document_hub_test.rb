# frozen_string_literal: true

require "test_helper"

class Purchasing::ReceiptDocumentHubTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @purchase_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 4, quantity_received: 1) ]
    )
    @po_line = @purchase_order.purchase_order_lines.first
    @receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { purchase_order: @purchase_order, receipt_type: "po_backed", status: "posted" },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @po_line,
          quantity_expected: 2,
          quantity_received: 1,
          quantity_accepted: 1,
          quantity_rejected: 0,
          unit_cost_cents: 800
        }
      ]
    )
    ReceivingDiscrepancy.create!(
      receipt_line: @receipt.receipt_lines.first,
      discrepancy_type: "short",
      quantity_delta: -1
    )
  end

  test "summarizes receipt totals and purchase order alignment" do
    hub = Purchasing::ReceiptDocumentHub.call(@receipt)

    assert_equal 2, hub.totals.expected
    assert_equal 1, hub.totals.received
    assert_equal 1, hub.totals.accepted
    assert_equal @purchase_order.id, hub.purchase_order.id
    assert_equal 4, hub.po_receive_progress.ordered
    assert_equal 1, hub.po_receive_progress.received
    assert_equal 3, hub.po_receive_progress.open
    assert_equal 1, hub.po_line_matches.size
    assert_equal 4, hub.po_line_matches.first.ordered
    assert_equal 3, hub.po_line_matches.first.open_on_po
    assert_equal 1, hub.discrepancies.size
  end
end
