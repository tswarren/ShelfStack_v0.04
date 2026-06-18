# frozen_string_literal: true

require "test_helper"

class Purchasing::SuggestedVendorResolverTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @vendor_a = create_vendor!
    @vendor_b = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "prefers active preferred variant vendor" do
    ProductVariantVendor.create!(
      product_variant: @variant,
      vendor: @vendor_a,
      active: true,
      preferred: false
    )
    ProductVariantVendor.create!(
      product_variant: @variant,
      vendor: @vendor_b,
      active: true,
      preferred: true
    )

    result = Purchasing::SuggestedVendorResolver.for_variant(@variant)

    assert_equal @vendor_b, result.vendor
  end

  test "falls back to preferred product vendor" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor_a,
      active: true,
      preferred: true
    )

    result = Purchasing::SuggestedVendorResolver.for_variant(@variant)

    assert_equal @vendor_a, result.vendor
  end

  test "returns empty result when no sourcing exists" do
    result = Purchasing::SuggestedVendorResolver.for_variant(@variant)

    assert_nil result.vendor
  end
end
