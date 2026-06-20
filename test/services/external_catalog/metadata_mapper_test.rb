# frozen_string_literal: true

require "test_helper"

class ExternalCatalogMetadataMapperTest < ActiveSupport::TestCase
  test "maps yesteryear sample creators themes and creator details" do
    payload = JSON.parse(Rails.root.join("docs/samples/isbndb/response_1781991552204.json").read)
    candidate = ExternalCatalog::Provider::IsbndbNormalizer.call(payload: payload)
    attrs = ExternalCatalog::MetadataMapper.catalog_attributes(candidate: candidate)

    assert_equal "Burke, Caro Claire [author]", attrs[:creators]
    expected_themes = candidate.subjects.join("; ")
    assert_equal expected_themes, attrs[:themes]
    assert_equal 10, attrs[:themes].split("; ").length

    parsed = MetadataParser.parse_creators(attrs[:creators])
    assert_equal "Burke", parsed.first["family_name"]
    assert_equal "Caro Claire", parsed.first["given_names"]
    assert_equal [ "author" ], parsed.first["roles"]

    theme_entries = MetadataParser.parse_subjects(attrs[:themes])
    assert_equal "Mystery, Thriller & Suspense", theme_entries.first["heading"]
    assert_equal "local", theme_entries.first["scheme"]
  end

  test "maps gatsby fixture creators and themes" do
    payload = isbndb_fixture("success")
    candidate = ExternalCatalog::Provider::IsbndbNormalizer.call(payload: payload)
    attrs = ExternalCatalog::MetadataMapper.catalog_attributes(candidate: candidate)

    assert_equal "Fitzgerald, F. Scott [author]", attrs[:creators]
    assert_equal "Fiction; Classics", attrs[:themes]
  end

  test "dedupes themes case insensitively while preserving order" do
    candidate = ExternalCatalog::BookCandidate.new(
      source_key: "isbndb",
      external_identifier: "9780000000000",
      isbn10: nil,
      isbn13: "9780000000000",
      title: "Test",
      subtitle: nil,
      authors: [],
      publisher: nil,
      date_published: nil,
      binding: nil,
      language: nil,
      pages: nil,
      msrp_cents: nil,
      currency_code: nil,
      image_url: nil,
      synopsis: nil,
      excerpt: nil,
      subjects: [ "Fiction", "fiction", "Classics" ],
      dewey_decimal: nil,
      dimensions: {},
      other_isbns: [],
      raw_payload: {}
    )

    attrs = ExternalCatalog::MetadataMapper.catalog_attributes(candidate: candidate)

    assert_equal "Fiction; Classics", attrs[:themes]
  end
end
