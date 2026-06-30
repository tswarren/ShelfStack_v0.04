# frozen_string_literal: true

require "test_helper"

class IngramCatalogImport::IdentifierResolverTest < ActiveSupport::TestCase
  test "finds catalog item by product identifier when catalog identifiers absent" do
    item = create_catalog_item!
    product = create_legacy_catalog_linked_product!(catalog_item: item, sku: "9780063575011")
    ProductIdentifier.where(product_id: product.id).delete_all
    ProductIdentifierService.add_identifier!(
      product: product,
      validation_family: "gtin",
      value: "9780063575011",
      primary: true
    )

    result = IngramCatalogImport::IdentifierResolver.resolve(
      product_code: nil,
      ean: "9780063575011"
    )

    assert result.found?
    assert_equal item, result.catalog_item
  end

  test "finds catalog item by EAN" do
    item = create_catalog_item!
    add_test_product_identifier!(
      catalog_item: item,
      identifier_type: "isbn13",
      value: "9780063575011",
      primary: true
    )

    result = IngramCatalogImport::IdentifierResolver.resolve(
      product_code: nil,
      ean: "9780063575011"
    )

    assert result.found?
    assert_equal item, result.catalog_item
  end

  test "falls back to product code" do
    item = create_catalog_item!
    add_test_product_identifier!(
      catalog_item: item,
      identifier_type: "isbn10",
      value: "0063575019",
      primary: false
    )

    result = IngramCatalogImport::IdentifierResolver.resolve(
      product_code: "0063575019",
      ean: nil
    )

    assert result.found?
    assert_equal item, result.catalog_item
  end

  test "detects identifier conflict" do
    item_one = create_catalog_item!
    item_two = create_catalog_item!
    add_test_product_identifier!(
      catalog_item: item_one,
      identifier_type: "isbn13",
      value: "9780123456786",
      primary: true
    )
    add_test_product_identifier!(
      catalog_item: item_two,
      identifier_type: "isbn10",
      value: "0063575019",
      primary: true
    )

    result = IngramCatalogImport::IdentifierResolver.resolve(
      product_code: "0063575019",
      ean: "9780123456786"
    )

    assert result.conflict?
    assert_includes result.message, "different products"
  end

  test "finds product-first item without catalog item" do
    product = create_product!(sku: "9780063575011", skip_product_identifier: true)
    ProductIdentifierService.add_identifier!(
      product: product,
      validation_family: "gtin",
      value: "9780063575011",
      primary: true
    )

    result = IngramCatalogImport::IdentifierResolver.resolve(
      product_code: nil,
      ean: "9780063575011"
    )

    assert result.found?
    assert_equal product, result.product
    assert_nil result.catalog_item
  end
end
