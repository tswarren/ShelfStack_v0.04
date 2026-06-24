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

  test "variable list label uses attribute value only" do
    product = create_product!(name: "Store T-Shirt", variation_type: "variable")
    variant = ProductVariant.new(product: product, attribute1_value: "Blue", name: "Store T-Shirt - Blue")
    assert_equal "Blue", ProductNameRenderer.variant_list_label(variant)
  end

  test "matrix list label joins attribute values only" do
    product = create_product!(name: "Store T-Shirt", variation_type: "matrix")
    variant = ProductVariant.new(
      product: product,
      attribute1_value: "Blue",
      attribute2_value: "Large",
      name: "Store T-Shirt - Blue / Large"
    )
    assert_equal "Blue / Large", ProductNameRenderer.variant_list_label(variant)
  end

  test "matrix list label ignores condition when attributes present" do
    product = create_product!(name: "Store T-Shirt", variation_type: "matrix")
    new_condition = ProductCondition.find_by(condition_key: "new") || create_product_condition!(condition_key: "new", short_name: "New")
    variant = ProductVariant.new(
      product: product,
      condition: new_condition,
      attribute1_value: "Blue",
      attribute2_value: "Large",
      name: "Store T-Shirt - Blue / Large"
    )
    assert_equal "Blue / Large", ProductNameRenderer.variant_list_label(variant)
  end

  test "conditional list label uses condition short name" do
    product = create_product!(name: "The Hobbit", variation_type: "conditional")
    signed = create_product_condition!(condition_key: "signed_list", sku_component: "SG", short_name: "Signed", name: "Signed Copy")
    variant = ProductVariant.new(product: product, condition: signed, name: "The Hobbit - Signed")
    assert_equal "Signed", ProductNameRenderer.variant_list_label(variant)
  end
end
