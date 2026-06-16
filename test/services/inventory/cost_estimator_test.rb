# frozen_string_literal: true

require "test_helper"

class Inventory::CostEstimatorTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @variant = create_product_variant!(selling_price_cents: 2000)
    @variant.sub_department.update!(default_margin_target_bps: 4000)
  end

  test "manual cost takes precedence" do
    result = Inventory::CostEstimator.estimate(variant: @variant, quantity_delta: 3, manual_unit_cost_cents: 500)
    assert_equal 500, result.unit_cost_cents
    assert_equal 1500, result.total_cost_cents
    assert_equal "manual", result.cost_source
  end

  test "margin estimate when manual cost absent" do
    result = Inventory::CostEstimator.estimate(variant: @variant, quantity_delta: 2, manual_unit_cost_cents: nil)
    assert_equal 1200, result.unit_cost_cents
    assert_equal 2400, result.total_cost_cents
    assert_equal "margin_estimate", result.cost_source
  end

  test "unknown when margin missing" do
    @variant.sub_department.update!(default_margin_target_bps: nil)
    result = Inventory::CostEstimator.estimate(variant: @variant, quantity_delta: 1)
    assert_nil result.unit_cost_cents
    assert_equal "unknown", result.cost_source
  end
end
