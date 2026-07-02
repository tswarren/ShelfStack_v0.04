# frozen_string_literal: true

require "test_helper"

class Purchasing::UpdatePoLineQuantitiesTest < ActiveSupport::TestCase
  include V0049TestHelper

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
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 10) ]
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

  test "marks line received when vendor confirmed less than ordered and all confirmed accepted" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 3)
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { receipt_type: "po_backed", purchase_order: @order },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @po_line,
          quantity_expected: 3,
          quantity_received: 3,
          quantity_accepted: 3,
          quantity_rejected: 0,
          unit_cost_cents: 600
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    @po_line.reload
    assert_equal 3, @po_line.quantity_received
    assert_equal "received", @po_line.status
  end

  test "marks line partially received when vendor confirmed less than ordered and part accepted" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 3)
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { receipt_type: "po_backed", purchase_order: @order },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @po_line,
          quantity_expected: 3,
          quantity_received: 1,
          quantity_accepted: 1,
          quantity_rejected: 0,
          unit_cost_cents: 600
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    @po_line.reload
    assert_equal 1, @po_line.quantity_received
    assert_equal "partially_received", @po_line.status
  end

  test "marks line backordered when confirmed portion received but vendor backorder remains" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 3, backordered: 7)
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { receipt_type: "po_backed", purchase_order: @order },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @po_line,
          quantity_expected: 3,
          quantity_received: 3,
          quantity_accepted: 3,
          quantity_rejected: 0,
          unit_cost_cents: 600
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    @po_line.reload
    assert_equal 3, @po_line.quantity_received
    assert_equal "backordered", @po_line.status
  end

  test "marks line cancelled when vendor canceled all quantity" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 0, canceled: 10)
    @po_line.update!(vendor_quantity_state: "canceled")

    assert_equal "cancelled", Purchasing::PoLineStatusDeriver.derive(@po_line.reload)
  end
end
