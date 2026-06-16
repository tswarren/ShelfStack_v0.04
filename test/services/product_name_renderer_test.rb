# frozen_string_literal: true

require "test_helper"

class ProductNameRendererTest < ActiveSupport::TestCase
  test "product name uses catalog title" do
    item = create_catalog_item!(title: "The Hobbit")
    product = Product.new(catalog_item: item, name: "ignored until saved")
    assert_equal "The Hobbit", ProductNameRenderer.product_name(product)
  end

  test "product name override takes precedence" do
    product = Product.new(name: "Original", name_override: "Override Name")
    assert_equal "Override Name", ProductNameRenderer.product_name(product)
  end

  test "conditional variant name includes condition short name" do
    product = create_product!(name: "The Hobbit", variation_type: "conditional")
    signed = create_product_condition!(condition_key: "signed_name", sku_component: "SG", short_name: "Signed", name: "Signed Copy")
    variant = ProductVariant.new(product: product, condition: signed)
    assert_equal "The Hobbit - Signed", ProductNameRenderer.variant_name(variant)
  end

  test "variable variant name includes attribute value" do
    product = create_product!(name: "Store T-Shirt", variation_type: "variable")
    variant = ProductVariant.new(product: product, attribute1_value: "Blue")
    assert_equal "Store T-Shirt - Blue", ProductNameRenderer.variant_name(variant)
  end

  test "matrix variant name joins attribute values" do
    product = create_product!(name: "Store T-Shirt", variation_type: "matrix")
    variant = ProductVariant.new(product: product, attribute1_value: "Blue", attribute2_value: "Large")
    assert_equal "Store T-Shirt - Blue / Large", ProductNameRenderer.variant_name(variant)
  end
end
