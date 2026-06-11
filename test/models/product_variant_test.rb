# frozen_string_literal: true

require "test_helper"

class ProductVariantTest < ActiveSupport::TestCase
  test "category is required" do
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
    assert_includes variant.errors[:category], "must exist"
  end

  test "inactive category is rejected" do
    category = create_category!(active: false)
    variant = build_variant(category: category)
    assert_not variant.valid?
    assert_includes variant.errors[:category], "must be active"
  end

  test "generates suffixed sku for non-new condition on standard product" do
    product = create_product!(sku: "BASE-SKU-123", variation_type: "standard")
    used = create_product_condition!(condition_key: "used_test", sku_component: "UG", short_name: "Good", name: "Used - Good")
    variant = ProductVariant.create!(
      product: product,
      category: create_category!,
      condition: used,
      selling_price_cents: 1000,
      inventory_behavior: "standard_physical",
      active: true
    )
    assert_equal "BASE-SKU-123-UG", variant.sku
  end

  private

  def build_variant(**attrs)
    dept = create_department!(
      department_number: format("%03d", rand(100..899)),
      name: "Dept #{SecureRandom.hex(2)}",
      short_name: "D#{SecureRandom.hex(2)}"
    )
    tax = create_tax_category!(name: "Tax #{SecureRandom.hex(2)}", short_name: "T#{SecureRandom.hex(2)}")
    ProductVariant.new({
      product: create_product!,
      category: create_category!(department: dept, default_tax_category: tax, name: "Cat #{SecureRandom.hex(2)}", short_name: "C#{SecureRandom.hex(2)}"),
      name: "Variant",
      sku: "VAR-#{SecureRandom.hex(3)}",
      selling_price_cents: 1000,
      inventory_behavior: "standard_physical",
      active: true
    }.merge(attrs))
  end
end
