# frozen_string_literal: true

require "test_helper"

class Purchasing::BuildReceiptFromPurchaseOrderTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "submitted", submitted_at: Time.current, submitted_by_user: @user },
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    @po_line = @order.purchase_order_lines.first
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user) if @order.draft?
    @po_line.reload
    @po_line.update_columns(
      unit_list_price_cents: 2000,
      supplier_discount_bps: 4000,
      unit_cost_cents: 1200
    )
  end

  test "creates draft receipt with open po lines preloaded" do
    receipt = Purchasing::BuildReceiptFromPurchaseOrder.call(purchase_order: @order, created_by_user: @user)

    assert_equal "draft", receipt.status
    assert_equal "po_backed", receipt.receipt_type
    assert_equal @order.id, receipt.purchase_order_id
    line = receipt.receipt_lines.first
    assert_equal @po_line.id, line.purchase_order_line_id
    assert_equal 5, line.quantity_expected
    assert_equal 5, line.quantity_received
    assert_equal 5, line.quantity_accepted
    assert_equal 0, line.quantity_rejected
    assert_equal 1200, line.unit_cost_cents
    assert AuditEvent.exists?(event_name: "receipt.created", auditable: receipt)
  end

  test "preloads only remaining quantity on partially received po" do
    @po_line.update_columns(quantity_received: 2, status: "partially_received")
    @order.update_column(:status, "partially_received")

    receipt = Purchasing::BuildReceiptFromPurchaseOrder.call(purchase_order: @order, created_by_user: @user)
    line = receipt.receipt_lines.first

    assert_equal 3, line.quantity_expected
    assert_equal 3, line.quantity_received
    assert_equal 3, line.quantity_accepted
  end

  test "rejects non receivable purchase order" do
    @order.update_column(:status, "draft")

    assert_raises(Purchasing::BuildReceiptFromPurchaseOrder::BuildError) do
      Purchasing::BuildReceiptFromPurchaseOrder.call(purchase_order: @order, created_by_user: @user)
    end
  end
end
