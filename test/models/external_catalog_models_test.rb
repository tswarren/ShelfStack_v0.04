# frozen_string_literal: true

require "test_helper"

class ExternalCatalogModelsTest < ActiveSupport::TestCase
  setup do
    @user = create_user!
    @source = create_isbndb_source!
  end

  test "external lookup request validates status" do
    request = ExternalLookupRequest.new(
      external_data_source: @source,
      lookup_type: "isbn",
      query: "9780743273565",
      status: "invalid",
      requested_by_user: @user
    )
    assert_not request.valid?
  end

  test "external catalog import validates action type" do
    request = ExternalLookupRequest.create!(
      external_data_source: @source,
      lookup_type: "isbn",
      query: "9780743273565",
      normalized_query: "9780743273565",
      status: "completed",
      requested_by_user: @user,
      started_at: Time.current,
      completed_at: Time.current
    )
    result = request.create_external_lookup_result!(
      source_key: "isbndb",
      title: "Test",
      raw_payload_json: {}
    )
    import = ExternalCatalogImport.new(
      external_lookup_result: result,
      external_data_source: @source,
      status: "applied",
      action_type: "continue_add_item",
      imported_by_user: @user,
      applied_at: Time.current
    )
    assert_not import.valid?
  end
end
