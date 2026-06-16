# frozen_string_literal: true

require "test_helper"

class ItemSearchTest < ActiveSupport::TestCase
  include Phase3TestHelper

  test "finds catalog item by title" do
    item = create_catalog_item!(title: "Unique Search Title XYZ")
    results = ItemSearch.call(query: "Unique Search Title")

    assert results.any? { |result| result.presenter.catalog_item == item }
  end

  test "finds product by sku" do
    product = create_product!(sku: "UNIQUESKU999")
    results = ItemSearch.call(query: "UNIQUESKU999")

    assert results.any? { |result| result.presenter.product == product }
  end

  test "dedupes variant hits to one presenter" do
    variant = create_product_variant!(sku: "VARIANTSKU123")
    results = ItemSearch.call(query: "VARIANTSKU123")

    assert_equal 1, results.size
    assert_equal variant.product, results.first.presenter.product
  end
end
