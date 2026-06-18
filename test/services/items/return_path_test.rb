# frozen_string_literal: true

require "test_helper"

class ItemsReturnPathTest < ActiveSupport::TestCase
  include Phase3TestHelper

  setup do
    @catalog_item = create_catalog_item!(title: "Return Path Book")
    @product = create_product!(catalog_item: @catalog_item)
    @variant = create_product_variant!(product: @product)
  end

  test "item flow returns item setup tab path for catalog item" do
    path = Items::ReturnPath.for(record: @catalog_item, return_to: "item", tab: "item_setup")

    assert_equal "/items/item?catalog_item_id=#{@catalog_item.id}&tab=item_setup", path
  end

  test "item flow returns item setup tab path for product" do
    path = Items::ReturnPath.for(record: @product, return_to: "item", tab: "item_setup")

    assert_equal "/items/item?catalog_item_id=#{@catalog_item.id}&tab=item_setup", path
  end

  test "item flow includes variant_id when provided" do
    path = Items::ReturnPath.for(
      record: @variant,
      return_to: "item",
      tab: "item_setup",
      variant_id: @variant.id
    )

    assert_equal "/items/item?catalog_item_id=#{@catalog_item.id}&tab=item_setup&variant_id=#{@variant.id}", path
  end

  test "legacy flow returns resource show path" do
    assert_equal "/items/catalog_items/#{@catalog_item.id}",
                 Items::ReturnPath.for(record: @catalog_item, return_to: nil)
    assert_equal "/items/products/#{@product.id}",
                 Items::ReturnPath.for(record: @product, return_to: nil)
    assert_equal "/items/product_variants/#{@variant.id}",
                 Items::ReturnPath.for(record: @variant, return_to: nil)
  end

  test "non-catalog product uses product_id route param" do
    standalone = Product.create!(
      name: "Standalone Gift",
      sku: "GIFT-#{SecureRandom.hex(3)}",
      product_type: "physical",
      variation_type: "standard",
      list_price_cents: 1500,
      active: true
    )

    path = Items::ReturnPath.for(record: standalone, return_to: "item", tab: "item_setup")

    assert_equal "/items/item?product_id=#{standalone.id}&tab=item_setup", path
  end

  test "defaults to item setup tab when tab omitted" do
    path = Items::ReturnPath.for(record: @product, return_to: "item")

    assert_equal "/items/item?catalog_item_id=#{@catalog_item.id}&tab=item_setup", path
  end
end
