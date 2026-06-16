# frozen_string_literal: true

require "test_helper"

class SkuGeneratorTest < ActiveSupport::TestCase
  setup do
    @product = create_product!(sku: "9780123456786", variation_type: "standard")
  end

  test "new standard variant uses product sku" do
    variant = ProductVariant.new(product: @product, condition: new_condition)
    assert_equal "9780123456786", SkuGenerator.variant_sku(variant)
  end

  test "conditional variant appends condition component" do
    product = Product.new(sku: "9780123456786", variation_type: "conditional")
    signed = create_product_condition!(condition_key: "signed", sku_component: "SG", short_name: "Signed", name: "Signed")
    sku = SkuGenerator.preview_variant_sku(product: product, condition: signed)
    assert_equal "9780123456786-SG", sku
  end

  test "standard product appends condition component for non-new conditions" do
    signed = create_product_condition!(condition_key: "signed_std", sku_component: "SG", short_name: "Signed", name: "Signed")
    variant = ProductVariant.new(product: @product, condition: signed)
    assert_equal "9780123456786-SG", SkuGenerator.variant_sku(variant)
  end

  test "variable variant appends attribute component" do
    product = Product.new(sku: "9780123456786", variation_type: "variable")
    sku = SkuGenerator.preview_variant_sku(product: product, attribute1_sku_component: "BLU")
    assert_equal "9780123456786-BLU", sku
  end

  test "matrix variant appends both attribute components" do
    product = Product.new(sku: "9780123456786", variation_type: "matrix")
    sku = SkuGenerator.preview_variant_sku(
      product: product,
      attribute1_sku_component: "BLU",
      attribute2_sku_component: "LG"
    )
    assert_equal "9780123456786-BLU-LG", sku
  end

  private

  def new_condition
    ProductCondition.find_by(condition_key: "new") || create_product_condition!(condition_key: "new", sku_component: nil)
  end
end
