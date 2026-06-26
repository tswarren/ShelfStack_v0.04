# frozen_string_literal: true

require "test_helper"

class CatalogItemPrimaryThumbnailTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @catalog_item = create_catalog_item!
  end

  test "rejects unsupported thumbnail content type" do
    @catalog_item.primary_thumbnail.attach(
      io: StringIO.new("not-an-image"),
      filename: "thumb.txt",
      content_type: "text/plain"
    )

    assert_not @catalog_item.valid?
    assert_includes @catalog_item.errors[:primary_thumbnail], "must be a JPEG, PNG, WebP, or GIF"
  end

  test "accepts allowed thumbnail content type" do
    @catalog_item.primary_thumbnail.attach(
      io: StringIO.new("fake-png"),
      filename: "thumb.png",
      content_type: "image/png"
    )

    assert @catalog_item.valid?
  end
end
