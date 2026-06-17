# frozen_string_literal: true

require "test_helper"

class Purchasing::VendorCostCalculatorTest < ActiveSupport::TestCase
  test "calculates unit cost from list price and discount" do
    assert_equal 600, Purchasing::VendorCostCalculator.unit_cost_cents(
      unit_list_price_cents: 1000,
      supplier_discount_bps: 4000
    )
  end

  test "returns nil when list price is nil" do
    assert_nil Purchasing::VendorCostCalculator.unit_cost_cents(
      unit_list_price_cents: nil,
      supplier_discount_bps: 4000
    )
  end

  test "treats nil discount as zero" do
    assert_equal 1000, Purchasing::VendorCostCalculator.unit_cost_cents(
      unit_list_price_cents: 1000,
      supplier_discount_bps: nil
    )
  end
end
