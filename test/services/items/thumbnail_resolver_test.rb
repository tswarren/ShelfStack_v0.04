# frozen_string_literal: true

require "test_helper"

class Items::ThumbnailResolverTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @product = create_product!
    @item = Items::ItemPresenter.from_product(@product)
  end

  test "prefers product cover image over catalog thumbnail" do
    @product.catalog_item.primary_thumbnail.attach(
      io: StringIO.new("fake"),
      filename: "catalog.jpg",
      content_type: "image/jpeg"
    )
    @product.cover_image.attach(
      io: StringIO.new("fake"),
      filename: "product.jpg",
      content_type: "image/jpeg"
    )

    result = Items::ThumbnailResolver.resolve(item: @item)

    assert_equal :product, result.source
    assert result.attachment.present?
  end

  test "falls back to catalog primary thumbnail" do
    @product.catalog_item.primary_thumbnail.attach(
      io: StringIO.new("fake"),
      filename: "catalog.jpg",
      content_type: "image/jpeg"
    )

    result = Items::ThumbnailResolver.resolve(item: @item)

    assert_equal :catalog, result.source
  end

  test "returns placeholder when no attachments" do
    result = Items::ThumbnailResolver.resolve(item: @item)

    assert_equal :placeholder, result.source
    assert_nil result.attachment
  end
end
