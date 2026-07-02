# frozen_string_literal: true

require "test_helper"

class Purchasing::PoLineStatusDeriverTest < ActiveSupport::TestCase
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

  test "final all-backordered response updates line status to backordered" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 0, backordered: 10)

    assert_equal "backordered", Purchasing::PoLineStatusDeriver.derive(@po_line.reload)
  end

  test "final all-canceled response updates line status to cancelled" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 0, canceled: 10)

    assert_equal "cancelled", Purchasing::PoLineStatusDeriver.derive(@po_line.reload)
  end

  test "confirmed partial with backorder and full confirmed receipt stays backordered" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 3, backordered: 7)
    @po_line.update!(quantity_received: 3, receiving_update: true)

    assert_equal "backordered", Purchasing::PoLineStatusDeriver.derive(@po_line.reload)
  end

  test "confirmed partial without backorder and full confirmed receipt marks received" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 3)
    @po_line.update!(quantity_received: 3, receiving_update: true)

    assert_equal "received", Purchasing::PoLineStatusDeriver.derive(@po_line.reload)
  end

  test "partial confirmed receipt with open supply marks partially received" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 3)
    @po_line.update!(quantity_received: 1, receiving_update: true)

    assert_equal "partially_received", Purchasing::PoLineStatusDeriver.derive(@po_line.reload)
  end

  test "closed short quantity takes precedence" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 3, backordered: 7)
    @po_line.update!(quantity_received: 3, quantity_closed_short: 4, closure_update: true)

    assert_equal "closed_short", Purchasing::PoLineStatusDeriver.derive(@po_line.reload)
  end

  test "preserves open status when vendor quantities are not recorded" do
    assert_equal "open", Purchasing::PoLineStatusDeriver.derive(@po_line.reload)
  end
end
