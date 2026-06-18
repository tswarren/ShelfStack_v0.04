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

  test "calculates discount from list price and unit cost" do
    assert_equal 4000, Purchasing::VendorCostCalculator.supplier_discount_bps(
      unit_list_price_cents: 1000,
      unit_cost_cents: 600
    )
  end

  test "returns nil discount when list price is nil or zero" do
    assert_nil Purchasing::VendorCostCalculator.supplier_discount_bps(
      unit_list_price_cents: nil,
      unit_cost_cents: 600
    )
    assert_nil Purchasing::VendorCostCalculator.supplier_discount_bps(
      unit_list_price_cents: 0,
      unit_cost_cents: 600
    )
  end

  test "clamps discount when cost exceeds list price" do
    assert_equal 0, Purchasing::VendorCostCalculator.supplier_discount_bps(
      unit_list_price_cents: 1000,
      unit_cost_cents: 1200
    )
  end

  test "round-trips list price discount and cost" do
    list_price = 2000
    discount = 3500
    cost = Purchasing::VendorCostCalculator.unit_cost_cents(
      unit_list_price_cents: list_price,
      supplier_discount_bps: discount
    )
    assert_equal discount, Purchasing::VendorCostCalculator.supplier_discount_bps(
      unit_list_price_cents: list_price,
      unit_cost_cents: cost
    )
  end
end
