# frozen_string_literal: true

require "test_helper"

class PurchaseOrderTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @user = create_user!
  end

  test "submitted purchase order rejects line changes" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "submitted", submitted_at: Time.current, submitted_by_user: @user },
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor) ]
    )
    line = order.purchase_order_lines.first

    order.purchase_order_lines_attributes = {
      "0" => { id: line.id, quantity_ordered: 99 }
    }

    assert_not order.valid?(:update)
    assert_includes order.errors.full_messages.join, "cannot modify lines on a submitted purchase order"
  end
end
