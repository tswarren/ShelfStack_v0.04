# frozen_string_literal: true

require "test_helper"

class Reports::TaxCollectedControllerTest < ActionDispatch::IntegrationTest
  include Phase1TestHelper
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "reptax#{SecureRandom.hex(3)}")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: @user.username, password: "Password123!" }
    grant_permission!(@user, "pos.reports.summary", store: @store)
  end

  test "renders report contract regions with date range" do
    get reports_tax_collected_path, params: {
      filter_type: "date_range",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current
    }

    assert_response :success
    assert_select ".ss-report.report-print"
    assert_select ".ss-filter-bar"
    assert_select ".ss-table.ss-table--report"
  end
end
