# frozen_string_literal: true

require "test_helper"

class ProductVariantTest < ActiveSupport::TestCase
  test "subdepartment is required" do
    product = create_product!
    variant = ProductVariant.new(
      product: product,
      name: "Test",
      sku: "TEST-SKU-#{SecureRandom.hex(2)}",
      selling_price_cents: 1000,
      inventory_behavior: "standard_physical",
      active: true
    )
    assert_not variant.valid?
    assert_includes variant.errors[:sub_department], "must exist"
  end

  test "inactive subdepartment is rejected" do
    sub_department = create_sub_department!(
      active: false,
      name: "Inactive Subdept #{SecureRandom.hex(2)}",
      short_name: "Inact #{SecureRandom.hex(1)}"
    )
    variant = build_variant(sub_department: sub_department)
    assert_not variant.valid?
    assert_includes variant.errors[:sub_department], "must be active"
  end

  test "generates suffixed sku for non-new condition on standard product" do
    product = create_product!(sku: "BASE-SKU-123", variation_type: "standard")
    used = create_product_condition!(condition_key: "used_test", sku_component: "UG", short_name: "Good", name: "Used - Good")
    variant = ProductVariant.create!(
      product: product,
      sub_department: create_sub_department!,
      condition: used,
      selling_price_cents: 1000,
      inventory_behavior: "standard_physical",
      active: true
    )
    assert_equal "BASE-SKU-123-UG", variant.sku
  end

  private

  def build_variant(**attrs)
    ProductVariant.new({
      product: create_product!,
      sub_department: create_sub_department!,
      name: "Variant",
      sku: "VAR-#{SecureRandom.hex(3)}",
      selling_price_cents: 1000,
      inventory_behavior: "standard_physical",
      active: true
    }.merge(attrs))
  end
end
