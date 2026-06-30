# frozen_string_literal: true

require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "sku must be unique" do
    create_product!(sku: "UNIQUE-SKU")
    duplicate = Product.new(
      name: "Duplicate",
      sku: "UNIQUE-SKU",
      product_type: "physical",
      variation_type: "standard",
      list_price_cents: 0,
      active: true
    )
    assert_not duplicate.valid?
  end

  test "catalog linked product syncs sku from primary product identifier" do
    item = create_catalog_item!
    product = create_legacy_catalog_linked_product!(catalog_item: item)
    ProductIdentifier.where(product_id: product.id).delete_all
    ProductIdentifierService.add_identifier!(
      product: product,
      validation_family: "isbn",
      value: "0123456789",
      primary: true
    )
    assert_equal "9780123456786", product.reload.sku
  end

  test "product is not sellable without active variant" do
    product = create_product!
    assert_not product.sellable?
    create_product_variant!(product: product)
    assert product.reload.sellable?
  end

  test "cover image accepts valid png" do
    product = create_product!
    product.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/cover.png")),
      filename: "cover.png",
      content_type: "image/png"
    )
    assert product.valid?
    assert product.cover_image.attached?
  end

  test "cover image rejects invalid content type" do
    product = create_product!
    product.cover_image.attach(
      io: StringIO.new("not an image"),
      filename: "cover.txt",
      content_type: "text/plain"
    )
    assert_not product.valid?
    assert_includes product.errors[:cover_image], "must be a JPEG, PNG, WebP, or GIF"
  end
end
