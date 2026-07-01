# frozen_string_literal: true

require "test_helper"

class ProductVariants::OperationalPolicyTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @product = create_product!
    @new_condition = ProductCondition.find_by!(condition_key: "new")
    @used_condition = ProductCondition.find_by!(condition_key: "used_good")
    @variant = create_product_variant!(product: @product, condition: @new_condition)
  end

  test "new condition variant is vendor orderable when orderable" do
    policy = ProductVariants::OperationalPolicy.for(@variant)

    assert policy.new_condition?
    assert_not policy.used_like?
    assert policy.vendor_orderable?
  end

  test "used-like variant is not vendor orderable even when orderable flag is true" do
    @variant.update!(condition: @used_condition, orderable: true)
    policy = ProductVariants::OperationalPolicy.for(@variant.reload)

    assert policy.used_like?
    assert_not policy.vendor_orderable?
    assert_equal "Used variants cannot be added to normal vendor purchase orders.",
      policy.purchasing_block_reason(context: :purchase_order)
  end

  test "remainder is new condition and may be vendor orderable" do
    remainder = ProductCondition.find_by!(condition_key: "remainder")
    @variant.update!(condition: remainder, orderable: true)
    policy = ProductVariants::OperationalPolicy.for(@variant.reload)

    assert policy.new_condition?
    assert_not policy.used_like?
    assert policy.vendor_orderable?
    assert_includes policy.operational_badges.map(&:key), :remainder
  end

  test "vendor sourcing not applicable for used-like" do
    @variant.update!(condition: @used_condition, orderable: false)
    policy = ProductVariants::OperationalPolicy.for(@variant.reload)

    assert_not policy.vendor_sourcing_applicable?
    assert policy.used_not_vendor_orderable_info.present?
  end

  test "blocks special order for used-like" do
    @variant.update!(condition: @used_condition)
    policy = ProductVariants::OperationalPolicy.for(@variant.reload)

    assert policy.customer_request_block_reason(request_type: "special_order").present?
    assert_nil policy.customer_request_block_reason(request_type: "hold")
  end

  test "financial product type is not vendor orderable" do
    @variant.product.update!(product_type: "financial")
    policy = ProductVariants::OperationalPolicy.for(@variant.reload)

    assert_not policy.vendor_orderable?
  end
end
