# frozen_string_literal: true

module Phase65TestHelper
  ISBNDB_SUCCESS_ISBN = "9780743273565"

  def create_isbndb_source!
    ExternalDataSource.find_or_create_by!(source_key: "isbndb") do |source|
      source.name = "ISBNdb"
      source.base_url = "https://api2.isbndb.com"
      source.active = true
      source.configuration_json = {}
    end
  end

  def isbndb_fixture(name)
    JSON.parse(Rails.root.join("test/fixtures/isbndb/#{name}.json").read)
  end

  def stub_isbndb_client(response)
    client = Object.new
    client.define_singleton_method(:fetch_book) { |_isbn| response }
    client.define_singleton_method(:check_key) { response }
    client
  end

  def isbndb_response(status_code:, body: nil, error: nil)
    ExternalCatalog::Provider::IsbndbClient::Response.new(
      status_code: status_code,
      body: body.is_a?(Hash) ? body.to_json : body,
      error: error
    )
  end

  def grant_external_lookup_permissions!(user)
    %w[
      items.external_lookup.access
      items.external_lookup.search
      items.external_lookup.import
      items.external_lookup.link_existing
      items.external_lookup.update_existing
      items.external_lookup.view_raw_payload
      items.external_lookup.configure
    ].each { |key| grant_permission!(user, key) }
  end
end
