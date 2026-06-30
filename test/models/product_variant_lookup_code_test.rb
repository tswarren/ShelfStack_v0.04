# frozen_string_literal: true

require "test_helper"

class ProductVariantLookupCodeTest < ActiveSupport::TestCase
  test "normalizes lookup code on save" do
    variant = create_product_variant!
    lookup_code = ProductVariantLookupCode.create!(
      product_variant: variant,
      code: " ab-12 ",
      normalized_code: "placeholder",
      code_type: "manual"
    )

    assert_equal "AB-12", lookup_code.code
    assert_equal "AB-12", lookup_code.normalized_code
  end

  test "store scoped code uniqueness" do
    store = create_store!
    variant = create_product_variant!
    ProductVariantLookupCode.create!(
      product_variant: variant,
      store: store,
      code: "CAFE-1",
      normalized_code: "CAFE-1",
      code_type: "menu_key"
    )

    other_variant = create_product_variant!(product: variant.product, sku: "OTHER-SKU-001")
    duplicate = ProductVariantLookupCode.new(
      product_variant: other_variant,
      store: store,
      code: "CAFE-1",
      normalized_code: "CAFE-1",
      code_type: "menu_key",
      active: true
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end
  end
end
