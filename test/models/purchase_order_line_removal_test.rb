# frozen_string_literal: true

require "test_helper"

class PurchaseOrderLineRemovalTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @variant_a = create_product_variant!(inventory_behavior: "standard_physical")
    @sub_department = @variant_a.sub_department
    @variant_b = create_product_variant!(sub_department: @sub_department, inventory_behavior: "standard_physical")
    @variant_c = create_product_variant!(sub_department: @sub_department, inventory_behavior: "standard_physical")
    @order = create_purchase_order!(store: @store, vendor: @vendor)
    @line_a = @order.purchase_order_lines.create!(
      product_variant: @variant_a,
      vendor: @vendor,
      quantity_ordered: 1,
      quantity_received: 0,
      status: "open"
    )
    @line_b = @order.purchase_order_lines.create!(
      product_variant: @variant_b,
      vendor: @vendor,
      quantity_ordered: 2,
      quantity_received: 0,
      status: "open"
    )
    @line_c = @order.purchase_order_lines.create!(
      product_variant: @variant_c,
      vendor: @vendor,
      quantity_ordered: 3,
      quantity_received: 0,
      status: "open"
    )
  end

  test "removing first line renumbers remaining lines without uniqueness errors" do
    @order.assign_attributes(
      purchase_order_lines_attributes: {
        "0" => { id: @line_a.id, product_variant_id: @variant_a.id, quantity_ordered: 1, _destroy: "1" },
        "1" => { id: @line_b.id, product_variant_id: @variant_b.id, quantity_ordered: 2, _destroy: "0" },
        "2" => { id: @line_c.id, product_variant_id: @variant_c.id, quantity_ordered: 3, _destroy: "0" }
      }
    )

    marked = @order.purchase_order_lines.select(&:marked_for_destruction?)
    assert_equal 1, marked.size, "expected one line marked for destruction"
    assert_equal @line_a.id, marked.first.id

    assert @order.save, @order.errors.full_messages.join(", ")
    @order.reload
    assert_equal 2, @order.purchase_order_lines.count
    assert_equal [ 1, 2 ], @order.purchase_order_lines.order(:line_number).pluck(:line_number)
    assert_not PurchaseOrderLine.exists?(@line_a.id)
  end
end
