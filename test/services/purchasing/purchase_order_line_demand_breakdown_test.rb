# frozen_string_literal: true

require "test_helper"

class PurchasingPurchaseOrderLineDemandBreakdownTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @vendor = Vendor.first || Vendor.create!(name: "Test Vendor", active: true)
    @variant = create_product_variant!
    @customer = create_customer!
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "special_order", provisional_title: "Special" } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @special_order = SpecialOrders::CreateFromRequestLine.call!(line: @line, created_by_user: @user)
    SpecialOrders::Approve.call!(special_order: @special_order, approved_by_user: @user)
    @purchase_order = PurchaseOrder.create!(
      store: @store,
      vendor: @vendor,
      status: "submitted",
      purchase_order_lines: [
        PurchaseOrderLine.new(
          line_number: 1,
          product_variant: @variant,
          vendor: @vendor,
          quantity_ordered: 3,
          quantity_received: 0,
          unit_cost_cents: 1000,
          variant_sku_snapshot: @variant.sku,
          variant_name_snapshot: @variant.name
        )
      ]
    )
    SpecialOrders::AttachToPurchaseOrderLine.call!(
      special_order: @special_order,
      purchase_order_line: @purchase_order.purchase_order_lines.first,
      quantity: 2,
      attached_by_user: @user
    )
  end

  test "breakdown reports customer allocated and stock quantities" do
    breakdown = Purchasing::PurchaseOrderLineDemandBreakdown.for(@purchase_order).first

    assert_equal 2, breakdown.customer_allocated_quantity
    assert_equal 1, breakdown.stock_quantity
    assert_equal 1, breakdown.allocation_rows.size
  end
end
