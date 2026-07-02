# frozen_string_literal: true

require "test_helper"

class PurchasingPoLineQuantitySummaryTest < ActiveSupport::TestCase
  include Phase5TestHelper
  include V0049TestHelper

  setup do
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 10) ]
    )
    @po_line = @order.purchase_order_lines.first
  end

  test "unconfirmed line uses ordered minus accepted for effective supply" do
  @po_line.update!(quantity_received: 3)
    summary = Purchasing::PoLineQuantitySummary.for(@po_line)

    assert_not summary.vendor_quantities_recorded?
    assert_equal 7, summary.effective_inbound_supply
    assert_equal 7, summary.open_to_receive_quantity
    assert_equal "unconfirmed", summary.derive_vendor_quantity_state
  end

  test "recorded confirmed zero does not fall back to ordered" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 0)
    summary = Purchasing::PoLineQuantitySummary.for(@po_line)

    assert_equal 0, summary.effective_inbound_supply
    assert_equal "unconfirmed", summary.derive_vendor_quantity_state
  end

  test "recorded confirmed supply subtracts accepted and closed short" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 8)
    @po_line.update!(quantity_received: 2, quantity_closed_short: 1)
    summary = Purchasing::PoLineQuantitySummary.for(@po_line.reload)

    assert_equal 5, summary.effective_inbound_supply
    assert_equal "partially_confirmed", summary.derive_vendor_quantity_state
  end

  test "derive_vendor_quantity_state for confirmed full order" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 10)
    assert_equal "confirmed", Purchasing::PoLineQuantitySummary.for(@po_line.reload).derive_vendor_quantity_state
  end

  test "derive_vendor_quantity_state for mixed buckets" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 5, backordered: 3)
    assert_equal "mixed", Purchasing::PoLineQuantitySummary.for(@po_line.reload).derive_vendor_quantity_state
  end
end
