# frozen_string_literal: true

require "test_helper"

class Phase3TestHelperTest < ActiveSupport::TestCase
  include Phase3TestHelper

  test "create_product! is product-first without catalog link" do
    product = create_product!

    assert_nil product.catalog_item_id
    assert product.title.present?
    assert product.sku.present?
  end

  test "create_legacy_catalog_linked_product! links catalog item" do
    product = create_legacy_catalog_linked_product!

    assert product.catalog_item_id.present?
    assert_equal product.catalog_item.title, product.title
  end

  test "create_product! with catalog_item delegates to legacy helper" do
    catalog_item = create_catalog_item!(title: "Delegated Legacy Book")
    product = create_product!(catalog_item: catalog_item)

    assert_equal catalog_item.id, product.catalog_item_id
  end
end
