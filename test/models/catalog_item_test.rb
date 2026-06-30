# frozen_string_literal: true

require "test_helper"

class CatalogItemTest < ActiveSupport::TestCase
  test "catalog item type controlled values" do
    item = build_catalog_item(catalog_item_type: "book")
    assert item.valid?

    item.catalog_item_type = "invalid"
    assert_not item.valid?
  end

  test "update allows catalog metadata changes without product identifiers" do
    item = create_catalog_item!
    assert item.update(title: "Changed Title")
  end

  test "parses creators into creator_details" do
    item = create_catalog_item!(creators: "Smith, John [author]")
    assert_equal "Smith, John", item.creator_details.first["display_name"]
    assert_equal [ "author" ], item.creator_details.first["roles"]
  end

  private

  def build_catalog_item(**attrs)
    CatalogItem.new({
      catalog_item_type: "book",
      title: "Test",
      publication_status: "active",
      format: create_format!(format_key: "pb_#{SecureRandom.hex(2)}"),
      active: true
    }.merge(attrs))
  end
end
