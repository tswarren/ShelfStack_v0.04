# frozen_string_literal: true

require "test_helper"

class Reports::CustomerRequestsQueryTest < ActiveSupport::TestCase
  include Phase1TestHelper
  include Phase7aTestHelper

  setup do
    @store = create_store!
    @user = create_user!(username: "custreqquery#{SecureRandom.hex(3)}")
  end

  test "call resolves customer request presenters from top-level namespace" do
    result = Reports::CustomerRequests::Query.call(store: @store)

    assert result.metrics.any?
    assert result.rows.is_a?(Array)
    assert_equal false, result.truncated
  end

  test "requests metric reflects full matching count when table is limited" do
    101.times do |index|
      CustomerRequest.create!(
        store: @store,
        created_by_user: @user,
        request_number: "REQ-#{index}",
        status: "new",
        source: "in_store",
        customer_name_snapshot: "Customer #{index}"
      )
    end

    result = Reports::CustomerRequests::Query.call(store: @store)

    assert_equal 101, result.metrics.find { |metric| metric[:label] == "Requests" }[:value]
    assert_equal Reports::CustomerRequests::Query::ROW_LIMIT, result.rows.size
    assert result.truncated
  end
end
