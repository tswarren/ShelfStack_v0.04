# frozen_string_literal: true

require "test_helper"

class Reports::RedirectsControllerTest < ActionDispatch::IntegrationTest
  include Phase1TestHelper
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "repredir#{SecureRandom.hex(3)}")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: @user.username, password: "Password123!" }
    grant_permission!(@user, "pos.access", store: @store)
    grant_permission!(@user, "pos.reports.view", store: @store)
    grant_permission!(@user, "pos.reports.register_summary", store: @store)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user)
  end

  test "pos register summary redirects to canonical report" do
    get register_summary_pos_reports_path
    assert_redirected_to reports_register_summary_path
  end

  test "pos register summary normalizes legacy session_id param" do
    get register_summary_pos_reports_path(session_id: @session.id)

    assert_redirected_to reports_register_summary_path(register_session_id: @session.id)
  end

  test "pos sales summary normalizes legacy session_id param" do
    grant_permission!(@user, "pos.reports.summary", store: @store)

    get summary_pos_reports_path(session_id: @session.id, filter_type: "register_session")

    assert_redirected_to reports_sales_summary_path(filter_type: "register_session", register_session_id: @session.id)
  end

  test "pos cash drawer normalizes legacy session_id param" do
    grant_permission!(@user, "pos.reports.drawer", store: @store)

    get drawer_pos_reports_path(session_id: @session.id)

    assert_redirected_to reports_cash_drawer_path(register_session_id: @session.id)
    follow_redirect!
    assert_response :success
    assert_select ".ss-report-scope", text: /#{Regexp.escape(@session.workstation.name)}/
  end

  test "shell reconciliation redirects to tax collected" do
    grant_permission!(@user, "pos.reports.summary", store: @store)

    get reports_shells_reconciliation_path
    assert_redirected_to reports_tax_collected_path
  end
end
