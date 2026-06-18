# frozen_string_literal: true

require "test_helper"

class Purchasing::ReturnabilityResolverTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical", returnability_status: "unknown")
  end

  test "variant status used when no vendor overrides" do
    @variant.update!(returnability_status: "returnable")
    assert_equal "returnable", Purchasing::ReturnabilityResolver.resolve(variant: @variant, vendor: @vendor)
  end

  test "product vendor overrides variant" do
    @variant.update!(returnability_status: "returnable")
    ProductVendor.create!(product: @variant.product, vendor: @vendor, returnability_status: "non_returnable", active: true)
    assert_equal "non_returnable", Purchasing::ReturnabilityResolver.resolve(variant: @variant, vendor: @vendor)
  end

  test "variant vendor wins over product vendor" do
    ProductVendor.create!(product: @variant.product, vendor: @vendor, returnability_status: "non_returnable", active: true)
    ProductVariantVendor.create!(
      product_variant: @variant,
      vendor: @vendor,
      returnability_status: "returnable",
      active: true
    )
    assert_equal "returnable", Purchasing::ReturnabilityResolver.resolve(variant: @variant, vendor: @vendor)
  end
end
