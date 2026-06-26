# frozen_string_literal: true

require "test_helper"

class Reports::CustomerRequestsQueryTest < ActiveSupport::TestCase
  include Phase1TestHelper
  include Phase7aTestHelper

  setup do
    @store = create_store!
  end

  test "call resolves customer request presenters from top-level namespace" do
    result = Reports::CustomerRequests::Query.call(store: @store)

    assert result.metrics.any?
    assert result.rows.is_a?(Array)
  end
end
