# frozen_string_literal: true

require "test_helper"

class Reports::DiscountSummaryQueryTest < ActiveSupport::TestCase
  include Phase1TestHelper
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "discquery#{SecureRandom.hex(3)}")
  end

  test "returns zero totals when no applications" do
    scope = Pos::ReportScope.from_params(
      store: @store,
      params: { business_date: Date.current.to_s }
    )

    result = Reports::DiscountSummary::Query.call(scope: scope)
    assert_equal 0, result.total_discount_cents
  end
end
