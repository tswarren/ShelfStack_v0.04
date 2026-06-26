# frozen_string_literal: true

require "test_helper"

class ProductVariants::OrderabilityDefaultsTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "defaults new physical variant to orderable" do
    assert ProductVariants::OrderabilityDefaults.resolve(@variant)
  end

  test "defaults used condition to not orderable" do
    used = ProductCondition.find_by!(condition_key: "used_good")
    @variant.update!(condition: used)

    assert_not ProductVariants::OrderabilityDefaults.resolve(@variant)
  end

  test "defaults financial product to not orderable" do
    @variant.product.update!(product_type: "financial")

    assert_not ProductVariants::OrderabilityDefaults.resolve(@variant)
  end
end
