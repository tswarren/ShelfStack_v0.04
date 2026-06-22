# frozen_string_literal: true

require "test_helper"

class CustomerRequestsSearchQueryTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @customer = create_customer!(display_name: "Searchable Pat", phone: "555-0199")
    @variant = create_product_variant!(sku: "SEARCH-SKU-001")
    @request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { provisional_title: "Rare Anthology", provisional_identifier: "9781234567890" } ]
    )
    match_request_line!(line: @request.customer_request_lines.first, variant: @variant, actor: @user)
  end

  test "finds request by customer name" do
    ids = search_ids("Searchable")

    assert_includes ids, @request.id
  end

  test "finds request by phone snapshot" do
    @request.update!(customer_phone_snapshot: "555-0199")

    ids = search_ids("555-0199")

    assert_includes ids, @request.id
  end

  test "finds request by provisional identifier" do
    ids = search_ids("9781234567890")

    assert_includes ids, @request.id
  end

  test "finds request by variant sku" do
    ids = search_ids("SEARCH-SKU")

    assert_includes ids, @request.id
  end

  test "ignores queries shorter than two characters" do
    ids = search_ids("S")

    assert_includes ids, @request.id
  end

  private

  def search_ids(query)
    CustomerRequests::SearchQuery.apply(
      CustomerRequest.where(store: @store),
      query
    ).pluck(:id)
  end
end
