# frozen_string_literal: true

require "test_helper"

class Purchasing::LineEconomicsCalculatorTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @vendor = create_vendor!(default_supplier_discount_bps: 4000)
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 2500)
    @variant.product.update!(list_price_cents: 2000)
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 4) ]
    )
    @line = @order.purchase_order_lines.first
  end

  test "recalculates line totals from unit cost and retail" do
    @line.assign_attributes(unit_cost_cents: 1200, expected_retail_price_cents: 2500)
    result = Purchasing::LineEconomicsCalculator.call(line: @line)

    assert_equal 4800, result.expected_line_cost_cents
    assert_equal 10_000, result.expected_line_retail_cents
    assert_equal 5200, result.expected_margin_cents
    assert_equal 5200, result.expected_margin_bps
  end

  test "apply persists economics on line" do
    @line.expected_retail_price_cents = 3000
    Purchasing::LineEconomicsCalculator.apply!(@line, changed_field: "expected_retail_price_cents")

    assert_equal 3000, @line.expected_retail_price_cents
    assert_equal "manual", @line.price_source
    assert @line.manual_price_override
  end
end
