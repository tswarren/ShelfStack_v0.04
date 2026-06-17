# frozen_string_literal: true

require "test_helper"

class Purchasing::UpdatePoLineQuantitiesTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    Current.store = @store

    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 10)]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)
    @po_line = @order.purchase_order_lines.first
  end

  test "updates po line and header after po-backed receipt posts" do
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { receipt_type: "po_backed", purchase_order: @order },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @po_line,
          quantity_expected: 10,
          quantity_received: 6,
          quantity_accepted: 6,
          quantity_rejected: 0,
          unit_cost_cents: 600
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    @po_line.reload
    @order.reload
    assert_equal 6, @po_line.quantity_received
    assert_equal "partially_received", @po_line.status
    assert_equal "partially_received", @order.status
  end

  test "marks po received when all quantity accepted" do
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { receipt_type: "po_backed", purchase_order: @order },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @po_line,
          quantity_expected: 10,
          quantity_received: 10,
          quantity_accepted: 10,
          quantity_rejected: 0,
          unit_cost_cents: 600
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    @po_line.reload
    @order.reload
    assert_equal 10, @po_line.quantity_received
    assert_equal "received", @po_line.status
    assert_equal "received", @order.status
  end
end
