# frozen_string_literal: true

require "test_helper"

class Purchasing::ReceiptDocumentHubMatchAwareTest < ActiveSupport::TestCase
  include Phase5TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @purchase_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [
        create_purchase_order_line_attrs(
          variant: @variant,
          vendor: @vendor,
          quantity_ordered: 3,
          quantity_received: 0
        )
      ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: @user)
    @po_line = @purchase_order.purchase_order_lines.first
    @receipt = Receiving::CreateVendorShipmentReceipt.call!(
      store: @store,
      vendor: @vendor,
      attrs: {}
    )
    @receipt_line = @receipt.receipt_lines.create!(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 2,
      quantity_accepted: 2,
      quantity_rejected: 0,
      unit_cost_cents: 1000
    )
    Receiving::ApplyReceiptLineMatches.call!(
      receipt: @receipt,
      actor: @user,
      matches: [
        {
          receipt_line_id: @receipt_line.id,
          purchase_order_line_id: @po_line.id,
          quantity_matched: 2
        }
      ]
    )
  end

  test "po line matches use receipt_line_matches for vendor shipment receipts" do
    hub = Purchasing::ReceiptDocumentHub.call(@receipt.reload)

    assert_nil hub.purchase_order
    assert_equal 1, hub.po_line_matches.size
    match = hub.po_line_matches.first
    assert_equal @po_line.id, match.purchase_order_line.id
    assert_equal @purchase_order.id, match.purchase_order.id
    assert_equal 2, match.quantity_matched
    assert_equal "confirmed", match.match_status
    assert_equal 3, match.ordered
    assert_equal 3, match.open_on_po
  end
end
