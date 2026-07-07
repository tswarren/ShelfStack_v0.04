# frozen_string_literal: true

require "test_helper"

class ReportsUxContractTest < ActionDispatch::IntegrationTest
  include Phase1TestHelper
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "reports_ux#{SecureRandom.hex(3)}", password: "Password123!")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: @user.username, password: "Password123!" }
    grant_permission!(@user, "pos.reports.summary", store: @store)
    grant_permission!(@user, "pos.reports.sales", store: @store)
  end

  test "reports hub uses page header" do
    get reports_root_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Reports"
    assert_select ".ss-page-description", text: /Operational reports for/
    assert_select "a", text: "Sales List"
  end

  test "report show uses header actions and filter bar button partial" do
    get reports_tax_collected_path, params: {
      filter_type: "date_range",
      start_date: Date.current.beginning_of_month,
      end_date: Date.current
    }

    assert_response :success
    assert_select ".ss-page-header.ss-report-header h1", text: "Tax Collected"
    assert_select ".ss-page-description.ss-report-scope"
    assert_select ".ss-page-actions.ss-report-actions a.ss-btn-secondary", text: "Print"
    assert_select ".ss-page-actions.ss-report-actions a.ss-btn-tertiary", text: "Back to reports"
    assert_select ".ss-filter-actions button.ss-btn-secondary", text: "Run report"
    assert_select ".ss-report.report-print"
  end

  test "sales list report uses standard actions with export" do
    get reports_sales_path

    assert_response :success
    assert_select ".ss-page-actions a.ss-btn-secondary", text: "Export CSV"
    assert_select ".ss-page-actions a.ss-btn-tertiary", text: "Back to reports"
  end
end
