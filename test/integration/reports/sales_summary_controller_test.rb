# frozen_string_literal: true

require "test_helper"

class Reports::SalesSummaryControllerTest < ActionDispatch::IntegrationTest
  include Phase1TestHelper
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "repsales#{SecureRandom.hex(3)}")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: @user.username, password: "Password123!" }
    grant_permission!(@user, "pos.reports.summary", store: @store)
  end

  test "renders sales summary with date range filter" do
    get reports_sales_summary_path, params: {
      filter_type: "date_range",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current
    }

    assert_response :success
    assert_select "h1", text: /Sales.*Revenue Summary/
    assert_select ".ss-filter-bar"
  end
end
