# frozen_string_literal: true

require "test_helper"

class Buybacks::EligibilityTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase7c_reference_data!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(sub_department: @sub, condition: @condition)
  end

  test "allows eligible variant and condition" do
    line = BuybackLine.new(
      product_variant: @variant,
      product_condition: @condition,
      sub_department: @sub
    )

    assert_nothing_raised { Buybacks::Eligibility.ensure_line_eligible!(line: line) }
  end

  test "rejects subdepartment without buyback_allowed" do
    @sub.update!(buyback_allowed: false)
    line = BuybackLine.new(
      product_variant: @variant,
      product_condition: @condition,
      sub_department: @sub
    )

    assert_raises(Buybacks::Eligibility::Error) { Buybacks::Eligibility.ensure_line_eligible!(line: line) }
  end
end
