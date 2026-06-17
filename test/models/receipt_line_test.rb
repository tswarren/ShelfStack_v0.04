# frozen_string_literal: true

require "test_helper"

class ReceiptLineTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @receipt = Receipt.create!(store: @store, vendor: @vendor, receipt_type: "direct", status: "draft")
  end

  test "defaults accepted from received on draft receipt when rejected is zero" do
    line = @receipt.receipt_lines.build(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 3,
      quantity_accepted: 0,
      quantity_rejected: 0
    )

    assert line.valid?
    assert_equal 3, line.quantity_accepted
  end

  test "caps accepted when received is lowered below prior accepted" do
    line = @receipt.receipt_lines.build(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 3,
      quantity_accepted: 5,
      quantity_rejected: 0
    )

    assert line.valid?
    assert_equal 3, line.quantity_accepted
  end

  test "sets accepted from received minus rejected" do
    line = @receipt.receipt_lines.build(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 10,
      quantity_accepted: 0,
      quantity_rejected: 2
    )

    assert line.valid?
    assert_equal 8, line.quantity_accepted
  end

  test "does not override explicit accepted quantity within received" do
    line = @receipt.receipt_lines.build(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 5,
      quantity_accepted: 2,
      quantity_rejected: 3
    )

    assert line.valid?
    assert_equal 2, line.quantity_accepted
  end
end
