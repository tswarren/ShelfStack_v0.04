# frozen_string_literal: true

require "test_helper"

class DemandLinesEligibilityResolverTest < ActiveSupport::TestCase
  include Phase3TestHelper

  setup do
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @user = create_user!
    @new_variant = create_product_variant!(inventory_behavior: "standard_physical")
    used_condition = ProductCondition.find_by(condition_key: "used_good") ||
      create_product_condition!(condition_key: "used_good_elig", name: "Used Good", short_name: "Used",
                                new_condition: false, buyback_eligible: true)
    @used_variant = create_product_variant!(
      product: @new_variant.product,
      condition: used_condition,
      inventory_behavior: "standard_physical",
      sku: "211#{SecureRandom.random_number(10**10).to_s.rjust(10, '0')}"
    )
    @customer = create_customer!(display_name: "Demand Customer")
  end

  test "hold allows used-like variant with customer snapshot" do
    result = DemandLines::EligibilityResolver.call(
      capture_intent: "hold",
      variant: @used_variant,
      customer_name_snapshot: "Walk-in"
    )

    assert result.allowed
  end

  test "special_order blocks used-like variant" do
    result = DemandLines::EligibilityResolver.call(
      capture_intent: "special_order",
      variant: @used_variant,
      customer: @customer
    )

    refute result.allowed
    assert_includes result.blocking_reasons.map(&:code), :used_like_not_allowed
  end

  test "used_wanted requires used-like variant" do
    result = DemandLines::EligibilityResolver.call(
      capture_intent: "used_wanted",
      variant: @new_variant,
      customer: @customer
    )

    refute result.allowed
    assert_includes result.blocking_reasons.map(&:code), :used_wanted_requires_used
  end

  test "manual_tbo requires vendor-orderable variant" do
    @used_variant.update!(orderable: false)

    result = DemandLines::EligibilityResolver.call(
      capture_intent: "manual_tbo",
      variant: @used_variant
    )

    refute result.allowed
  end

  test "invalid source purpose triple rejected" do
    result = DemandLines::EligibilityResolver.call(
      capture_intent: "manual_tbo",
      variant: @new_variant,
      source: "customer_order",
      purpose: "customer_fulfillment"
    )

    refute result.allowed
    assert_includes result.blocking_reasons.map(&:code), :invalid_combination
  end
end
