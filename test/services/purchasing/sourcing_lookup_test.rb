# frozen_string_literal: true

require "test_helper"

class Purchasing::SourcingLookupTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @vendor = create_vendor!(default_supplier_discount_bps: 3000)
    @other_vendor = create_vendor!(default_supplier_discount_bps: 5000)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @sub_department = @variant.sub_department
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "PROD-1",
      supplier_discount_bps: 4000,
      preferred: true,
      active: true
    )
    ProductVariantVendor.create!(
      product_variant: @variant,
      vendor: @vendor,
      vendor_item_number: "VAR-1",
      supplier_discount_bps: 4500,
      active: true
    )
  end

  test "prefers variant vendor overrides" do
    result = Purchasing::SourcingLookup.for(variant: @variant, vendor: @vendor)

    assert_equal "VAR-1", result.vendor_item_number
    assert_equal 4500, result.supplier_discount_bps
    assert result.sourcing_record_present
  end

  test "falls back to product vendor then vendor default" do
    variant_only_product = create_product_variant!(
      sub_department: @sub_department,
      inventory_behavior: "standard_physical"
    )
    ProductVendor.create!(
      product: variant_only_product.product,
      vendor: @vendor,
      vendor_item_number: "FALLBACK",
      supplier_discount_bps: 3500,
      active: true
    )

    result = Purchasing::SourcingLookup.for(variant: variant_only_product, vendor: @vendor)
    assert_equal "FALLBACK", result.vendor_item_number
    assert_equal 3500, result.supplier_discount_bps

    result = Purchasing::SourcingLookup.for(variant: variant_only_product, vendor: @other_vendor)
    assert_nil result.vendor_item_number
    assert_equal 5000, result.supplier_discount_bps
    assert_not result.sourcing_record_present
  end
end
