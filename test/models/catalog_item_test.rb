# frozen_string_literal: true

require "test_helper"

class CatalogItemTest < ActiveSupport::TestCase
  test "catalog item type controlled values" do
    item = build_catalog_item(catalog_item_type: "book")
    assert item.valid?

    item.catalog_item_type = "invalid"
    assert_not item.valid?
  end

  test "update requires active primary identifier" do
    item = create_catalog_item!
    item.catalog_item_identifiers.update_all(primary_identifier: false, active: false)
    assert_not item.update(title: "Changed Title")
    assert_includes item.errors[:base], "must have exactly one active primary identifier"
  end

  test "parses creators into creator_details" do
    item = create_catalog_item!(creators: "Smith, John [author]")
    assert_equal "Smith, John", item.creator_details.first["display_name"]
    assert_equal ["author"], item.creator_details.first["roles"]
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
