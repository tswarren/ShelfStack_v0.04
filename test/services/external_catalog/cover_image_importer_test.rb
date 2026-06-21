# frozen_string_literal: true

require "test_helper"

class ExternalCatalogCoverImageImporterTest < ActiveSupport::TestCase
  include Phase3TestHelper

  FakeCoverResponse = Struct.new(:code, :body, :content_type, keyword_init: true) do
    def is_a?(klass)
      klass <= Net::HTTPSuccess
    end
  end

  setup do
    @user = create_user!
    @product = create_product!
  end

  test "attaches downloaded cover image to product" do
    image_body = file_fixture("cover.png").read
    response = FakeCoverResponse.new(code: "200", body: image_body, content_type: "image/png")
    importer = ExternalCatalog::CoverImageImporter.new(product: @product, url: "https://example.com/cover.png", actor: @user)
    original_fetch = importer.method(:fetch)
    importer.define_singleton_method(:fetch) { |_uri| response }
    result = importer.call
    importer.define_singleton_method(:fetch, original_fetch)

    assert result.attached
    assert @product.cover_image.attached?
  end

  test "rejects empty downloaded cover image" do
    response = FakeCoverResponse.new(code: "200", body: "", content_type: "image/jpeg")
    importer = ExternalCatalog::CoverImageImporter.new(product: @product, url: "https://example.com/cover.jpg")
    original_fetch = importer.method(:fetch)
    importer.define_singleton_method(:fetch) { |_uri| response }
    result = importer.call
    importer.define_singleton_method(:fetch, original_fetch)

    assert_not result.attached
    assert_includes result.message, "empty or invalid"
    assert_not @product.cover_image.attached?
  end

  test "does not replace an existing cover image" do
    @product.cover_image.attach(
      io: file_fixture("cover.png").open,
      filename: "cover.png",
      content_type: "image/png"
    )

    result = ExternalCatalog::CoverImageImporter.call(
      product: @product,
      url: "https://example.com/cover.png"
    )

    assert_not result.attached
    assert_nil result.message
  end
end
