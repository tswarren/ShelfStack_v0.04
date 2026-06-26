# frozen_string_literal: true

require "test_helper"

class ReportsShellsControllerTest < ActionDispatch::IntegrationTest
  include Phase1TestHelper

  setup do
    Seeds::Phase9aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "reportshell#{SecureRandom.hex(3)}")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: @user.username, password: "Password123!" }
  end

  test "reconciliation shell requires permission" do
    get reports_shells_reconciliation_path
    assert_redirected_to root_path
  end

  test "reconciliation shell renders report contract regions" do
    grant_permission!(@user, "reports.foundation.view", store: @store)

    get reports_shells_reconciliation_path
    assert_response :success
    assert_select ".ss-report.report-print"
    assert_select ".ss-filter-bar"
    assert_select ".ss-metric-strip"
    assert_select ".ss-table.ss-table--report"
    assert_select ".ss-table-row--total"
    assert_select "a.ss-btn", text: "Print"
  end

  test "queue shell renders status badges and item links" do
    grant_permission!(@user, "reports.foundation.view", store: @store)

    get reports_shells_queue_path
    assert_response :success
    assert_select ".ss-status-badge"
    assert_select "a[href=?]", items_item_path(product_variant_id: 101, tab: "overview")
  end

  test "queue shell renders empty state when empty param set" do
    grant_permission!(@user, "reports.foundation.view", store: @store)

    get reports_shells_queue_path, params: { empty: "1" }
    assert_response :success
    assert_select ".ss-empty-state"
    assert_select ".ss-empty-state__title", text: "No requests match these filters"
  end
end
