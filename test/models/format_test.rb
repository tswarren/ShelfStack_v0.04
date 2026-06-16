# frozen_string_literal: true

require "test_helper"

class FormatTest < ActiveSupport::TestCase
  test "format saves with active default" do
    format = create_format!(format_key: "trade_pb", name: "Trade Paperback", short_name: "Trade PB")
    assert format.persisted?
    assert format.active?
  end

  test "format key must be unique" do
    create_format!(format_key: "duplicate")
    duplicate = Format.new(format_key: "duplicate", name: "Dup", short_name: "Dup")
    assert_not duplicate.valid?
  end

  test "inactive format cannot be assigned to new catalog item" do
    format = create_format!(format_key: "inactive_fmt", active: false)
    item = CatalogItem.new(
      catalog_item_type: "book",
      title: "Blocked",
      publication_status: "active",
      format: format
    )
    assert_not item.valid?
    assert_includes item.errors[:format], "must be active"
  end
end
