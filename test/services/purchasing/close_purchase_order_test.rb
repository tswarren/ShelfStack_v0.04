# frozen_string_literal: true

require "test_helper"

class Purchasing::ClosePurchaseOrderTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-1",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)
    @line = @order.purchase_order_lines.first
  end

  test "closes submitted purchase order with open lines" do
    Purchasing::ClosePurchaseOrder.call(purchase_order: @order, closed_by_user: @user)

    @order.reload
    @line.reload
    assert_equal "closed", @order.status
    assert_equal "closed", @line.status
    assert AuditEvent.exists?(event_name: "purchase_order.closed", auditable: @order)
  end

  test "marks partially received lines closed short and sets quantity_closed_short" do
    @line.update_columns(quantity_received: 2, status: "partially_received")
    @order.update_column(:status, "partially_received")

    Purchasing::ClosePurchaseOrder.call(purchase_order: @order, closed_by_user: @user)

    @line.reload
    assert_equal "closed_short", @line.status
    assert_equal 3, @line.quantity_closed_short
    assert_equal "closed", @order.reload.status
  end

  test "closes fully received purchase order without open lines" do
    @line.update_columns(quantity_received: 5, status: "received")
    @order.update_column(:status, "received")

    service = Purchasing::ClosePurchaseOrder.new(purchase_order: @order, closed_by_user: @user)
    assert service.closable?

    Purchasing::ClosePurchaseOrder.call(purchase_order: @order, closed_by_user: @user)

    assert_equal "received", @line.reload.status
    assert_equal "closed", @order.reload.status
  end

  test "rejects closing draft purchase orders" do
    draft = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor) ]
    )

    assert_raises(Purchasing::ClosePurchaseOrder::CloseError) do
      Purchasing::ClosePurchaseOrder.call(purchase_order: draft, closed_by_user: @user)
    end
  end
end
