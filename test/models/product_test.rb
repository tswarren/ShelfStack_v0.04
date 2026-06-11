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

  test "catalog linked product defaults sku from primary identifier" do
    item = CatalogItem.create!(
      catalog_item_type: "book",
      title: "SKU Default Test",
      publication_status: "active",
      format: create_format!(format_key: "sku_test_#{SecureRandom.hex(2)}"),
      active: true
    )
    CatalogIdentifierService.add_identifier!(
      catalog_item: item,
      identifier_type: "isbn10",
      value: "0123456789",
      primary: true
    )
    product = Product.create!(
      catalog_item: item,
      product_type: "physical",
      variation_type: "standard",
      list_price_cents: 1000,
      active: true
    )
    assert_equal "9780123456786", product.sku
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
