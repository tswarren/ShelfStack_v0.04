# frozen_string_literal: true

require "test_helper"

class ItemsHelperTest < ActionView::TestCase
  include ItemsHelper
  include Phase3TestHelper

  test "gif cover uses original attachment instead of variant" do
    product = create_product!
    product.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/cover.gif")),
      filename: "cover.gif",
      content_type: "image/gif"
    )

    representation = product_cover_image_representation(product.cover_image, size: :hero)
    assert_equal product.cover_image.blob, representation.blob
  end

  test "png cover uses resized variant" do
    product = create_product!
    product.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/cover.png")),
      filename: "cover.png",
      content_type: "image/png"
    )

    representation = product_cover_image_representation(product.cover_image, size: :hero)
    assert_kind_of ActiveStorage::VariantWithRecord, representation
  end

  test "item description block truncates long text with read more" do
    long_text = "word " * 80
    html = item_description_block(long_text.strip)

    assert_includes html, "Read more"
    assert_includes html, "ss-item-description"
  end

  test "item description block renders short text without read more" do
    html = item_description_block("Short description.")

    assert_not_includes html, "Read more"
    assert_includes html, "Short description."
  end
end
