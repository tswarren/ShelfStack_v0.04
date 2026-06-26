# frozen_string_literal: true

require "test_helper"

class Purchasing::SuggestedVendorResolverTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @vendor_a = create_vendor!
    @vendor_b = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "prefers variant preferred vendor" do
    @variant.update!(preferred_vendor: @vendor_b)

    result = Purchasing::SuggestedVendorResolver.for_variant(@variant)

    assert_equal @vendor_b, result.vendor
    assert_equal "variant_preferred", result.source
  end

  test "prefers preferred variant vendor source when no preferred vendor" do
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
    assert_equal "variant_vendor_source", result.source
  end

  test "falls back to preferred product vendor" do
    @variant.product.update!(preferred_vendor: @vendor_a)

    result = Purchasing::SuggestedVendorResolver.for_variant(@variant)

    assert_equal @vendor_a, result.vendor
    assert_equal "product_preferred", result.source
  end

  test "returns empty result when no sourcing exists" do
    result = Purchasing::SuggestedVendorResolver.for_variant(@variant)

    assert_nil result.vendor
    assert_equal "none", result.source
  end

  test "skips inactive vendor on active variant vendor source row" do
    inactive_vendor = create_vendor!
    ProductVariantVendor.create!(
      product_variant: @variant,
      vendor: inactive_vendor,
      active: true,
      preferred: true
    )
    inactive_vendor.update_columns(active: false)
    ProductVariantVendor.create!(
      product_variant: @variant,
      vendor: @vendor_b,
      active: true,
      preferred: false
    )

    result = Purchasing::SuggestedVendorResolver.for_variant(@variant)

    assert_equal @vendor_b, result.vendor
    assert_equal "variant_vendor_fallback", result.source
  end
end
