# frozen_string_literal: true

require "test_helper"

class Purchasing::PurchaseOrderSummaryTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @purchase_order = PurchaseOrder.create!(store: @store, vendor: @vendor, status: "draft")
  end

  test "summarizes units cost retail and net discount" do
    @purchase_order.purchase_order_lines.create!(
      product_variant: @variant,
      vendor: @vendor,
      quantity_ordered: 2,
      quantity_received: 0,
      status: "open",
      unit_list_price_cents: 2000,
      unit_cost_cents: 1200
    )
    second_variant = create_product_variant!(sub_department: @variant.sub_department)
    @purchase_order.purchase_order_lines.create!(
      product_variant: second_variant,
      vendor: @vendor,
      quantity_ordered: 3,
      quantity_received: 0,
      status: "open",
      unit_list_price_cents: 1000,
      unit_cost_cents: 600
    )

    summary = Purchasing::PurchaseOrderSummary.call(@purchase_order)

    assert_equal 5, summary.total_units
    assert_equal 4200, summary.total_cost_cents
    assert_equal 7000, summary.total_retail_cents
    assert_equal 2800, summary.net_discount_cents
    assert_equal 4000, summary.net_discount_bps
  end

  test "returns nil net discount percent when retail is zero" do
    line = @purchase_order.purchase_order_lines.create!(
      product_variant: @variant,
      vendor: @vendor,
      quantity_ordered: 1,
      quantity_received: 0,
      status: "open",
      unit_cost_cents: 500
    )
    line.update_columns(unit_list_price_cents: nil)

    summary = Purchasing::PurchaseOrderSummary.call(@purchase_order.reload)

    assert_equal 0, summary.total_retail_cents
    assert_nil summary.net_discount_bps
  end
end
