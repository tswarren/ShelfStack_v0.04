# frozen_string_literal: true

require "test_helper"

class ExternalCatalogLookupByIsbnTest < ActiveSupport::TestCase
  include Phase3TestHelper

  setup do
    @user = create_user!
    @source = create_isbndb_source!
    create_format!(format_key: "trade_paperback", name: "Trade Paperback", short_name: "TP")
  end

  test "rejects invalid isbn before external call" do
    client = stub_isbndb_client(isbndb_response(status_code: 200, body: "{}"))
    outcome = ExternalCatalog::LookupByIsbn.call(isbn: "not-an-isbn", actor: @user, source: @source, client: client)
    assert_equal :invalid, outcome.status
    assert_equal 0, ExternalLookupRequest.count
  end

  test "local match short-circuits without external call" do
    format = Format.find_by!(format_key: "trade_paperback")
    item = create_catalog_item!(format: format, title: "Local Book")
    CatalogIdentifierService.add_identifier!(
      catalog_item: item,
      identifier_type: "isbn13",
      value: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
      primary: true,
      actor: @user
    )

    client = stub_isbndb_client(isbndb_response(status_code: 500, body: "{}"))
    outcome = ExternalCatalog::LookupByIsbn.call(
      isbn: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
      actor: @user,
      source: @source,
      client: client
    )

    assert_equal :local_match, outcome.status
    assert_equal item.id, outcome.catalog_item.id
    assert_equal 0, ExternalLookupRequest.count
  end

  test "successful external lookup persists completed request and result" do
    payload = isbndb_fixture("success")
    client = stub_isbndb_client(isbndb_response(status_code: 200, body: payload))

    assert_difference -> { ExternalLookupRequest.count }, 1 do
      assert_difference -> { ExternalLookupResult.count }, 1 do
        @outcome = ExternalCatalog::LookupByIsbn.call(
          isbn: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
          actor: @user,
          source: @source,
          client: client
        )
      end
    end

    assert_equal :completed, @outcome.status
    assert_equal "completed", @outcome.request.status
    assert_equal "The Great Gatsby", @outcome.lookup_result.title
  end

  test "not found persists not_found status" do
    client = stub_isbndb_client(isbndb_response(status_code: 404, body: isbndb_fixture("not_found")))

    outcome = ExternalCatalog::LookupByIsbn.call(
      isbn: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
      actor: @user,
      source: @source,
      client: client
    )

    assert_equal :not_found, outcome.status
    assert_equal "not_found", outcome.request.status
    assert_nil outcome.lookup_result
  end

  test "rate limited persists rate_limited status" do
    client = stub_isbndb_client(isbndb_response(status_code: 429, body: isbndb_fixture("rate_limit")))

    outcome = ExternalCatalog::LookupByIsbn.call(
      isbn: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
      actor: @user,
      source: @source,
      client: client
    )

    assert_equal :rate_limited, outcome.status
    assert_equal "rate_limited", outcome.request.status
  end

  test "timeout persists failed status" do
    client = stub_isbndb_client(isbndb_response(status_code: nil, error: "Net::ReadTimeout"))

    outcome = ExternalCatalog::LookupByIsbn.call(
      isbn: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
      actor: @user,
      source: @source,
      client: client
    )

    assert_equal :failed, outcome.status
    assert_equal "failed", outcome.request.status
  end
end
