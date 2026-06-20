# frozen_string_literal: true

require "test_helper"

class ExternalCatalogIsbndbNormalizerTest < ActiveSupport::TestCase
  test "normalizes mavericks sample with weight and plain text synopsis" do
    payload = JSON.parse(Rails.root.join("docs/samples/isbndb/isbndb.json").read)
    candidate = ExternalCatalog::Provider::IsbndbNormalizer.call(payload: payload)

    assert_equal "9781786788986", candidate.isbn13
    assert_includes candidate.image_url, "/covers/original/"
    assert_equal BigDecimal("1.25"), candidate.dimensions["weight"]
    assert_equal "lb", candidate.dimensions["weight_units"]
    assert_not_includes candidate.synopsis, "<b>"
    assert_includes candidate.synopsis, "TikTok historian"
  end

  test "normalizes cher sample with year-only publication date mapping" do
    payload = JSON.parse(Rails.root.join("docs/samples/isbndb/response_1781989384571.json").read)
    candidate = ExternalCatalog::Provider::IsbndbNormalizer.call(payload: payload)
    attrs = ExternalCatalog::MetadataMapper.catalog_attributes(candidate: candidate)

    assert_equal Date.new(2024, 1, 1), attrs[:publication_date]
    assert_equal BigDecimal("1.00"), attrs[:weight]
    assert_equal "lb", attrs[:weight_units]
    assert_not_includes attrs[:description], "<"
    assert_includes attrs[:description], "Cher"
  end

  test "normalizes yesteryear sample with dimensions msrp and gram weight" do
    payload = JSON.parse(Rails.root.join("docs/samples/isbndb/response_1781991552204.json").read)
    candidate = ExternalCatalog::Provider::IsbndbNormalizer.call(payload: payload)
    attrs = ExternalCatalog::MetadataMapper.catalog_attributes(candidate: candidate)

    assert_equal 3000, candidate.msrp_cents
    assert_equal BigDecimal("23.5"), candidate.dimensions["height"]
    assert_equal BigDecimal("15.6"), candidate.dimensions["width"]
    assert_equal BigDecimal("2.9"), candidate.dimensions["depth"]
    assert_equal "cm", candidate.dimensions["dimension_units"]
    assert_equal BigDecimal("718"), candidate.dimensions["weight"]
    assert_equal "g", candidate.dimensions["weight_units"]
    assert_equal BigDecimal("23.5"), attrs[:height]
    assert_equal BigDecimal("15.6"), attrs[:width]
    assert_equal BigDecimal("2.9"), attrs[:depth]
    assert_equal "cm", attrs[:dimension_units]
    assert_equal BigDecimal("718"), attrs[:weight]
    assert_equal "g", attrs[:weight_units]
    assert_equal Date.new(2026, 4, 7), attrs[:publication_date]
  end
end
