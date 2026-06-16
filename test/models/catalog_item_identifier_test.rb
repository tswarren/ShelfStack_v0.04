# frozen_string_literal: true

require "test_helper"

class CatalogItemIdentifierTest < ActiveSupport::TestCase
  test "only one active primary identifier per catalog item" do
    item = create_catalog_item!
    primary = item.primary_identifier

    duplicate = item.catalog_item_identifiers.build(
      identifier_type: "publisher_number",
      identifier_value: "ABC123",
      normalized_identifier: "ABC123",
      primary_identifier: true,
      active: true
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end

    assert primary.reload.primary_identifier?
  end
end
