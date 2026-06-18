# frozen_string_literal: true

require "test_helper"

class PurchaseOrderReceivableTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "receivable when submitted with open quantity" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "submitted", submitted_at: Time.current, submitted_by_user: @user },
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 4) ]
    )

    assert order.receivable?
    assert_equal 4, order.open_quantity_for_line(order.purchase_order_lines.first)
  end

  test "not receivable when fully received" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "partially_received" },
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 2, quantity_received: 2, status: "received") ]
    )

    assert_not order.receivable?
  end
end
