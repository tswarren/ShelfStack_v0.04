# frozen_string_literal: true

require "test_helper"

class Purchasing::SourcingWarningsTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @other_vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor) ]
    )
  end

  test "warns when no vendor sourcing record exists" do
    warnings = Purchasing::SourcingWarnings.for_purchase_order(@order)

    assert_equal 1, warnings.size
    assert_match @variant.sku, warnings.first
    assert_match @vendor.name, warnings.first
  end

  test "no warning when product vendor sourcing exists" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "PROD-1",
      supplier_discount_bps: 4000,
      active: true
    )

    assert_empty Purchasing::SourcingWarnings.for_purchase_order(@order)
  end

  test "no warning when variant vendor sourcing exists" do
    ProductVariantVendor.create!(
      product_variant: @variant,
      vendor: @vendor,
      vendor_item_number: "VAR-1",
      supplier_discount_bps: 4500,
      active: true
    )

    assert_empty Purchasing::SourcingWarnings.for_purchase_order(@order)
  end
end
