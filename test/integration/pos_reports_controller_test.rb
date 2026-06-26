# frozen_string_literal: true

require "test_helper"

class PosReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "report_user")
    grant_all_phase6_permissions!(@user, store: @store)

    @variant = create_product_variant!(selling_price_cents: 1200)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)

    login_user!(@user, workstation: @workstation)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 5000)

    @sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1200, extended_price_cents: 1200 } ]
    )
    complete_pos_sale!(transaction: @sale, user: @user, register_session: @session)
  end

  test "summary report redirects to canonical sales summary" do
    get summary_pos_reports_path(filter_type: "register_session", register_session_id: @session.id)
    assert_redirected_to reports_sales_summary_path(filter_type: "register_session", register_session_id: @session.id)
    follow_redirect!
    assert_response :success
    assert_match(/Sales &amp; Revenue/i, response.body)
    assert_match(/Gross Sales/i, response.body)
    assert_match(/By clerk/i, response.body)
    assert_match(/Drawer reconciliation/i, response.body)
    assert_match(/Print/i, response.body)
  end

  test "summary report exports csv via canonical route" do
    get summary_pos_reports_path(
      filter_type: "register_session",
      register_session_id: @session.id,
      format: :csv
    )
    assert_response :redirect
    assert_match %r{/reports/sales_summary}, response.location
    assert_match(/format=csv/, response.location)
    follow_redirect!
    assert_response :success
    assert_match "Gross Sales", response.body
    assert_match "Clerk", response.body
  end

  test "register summary report redirects to canonical route" do
    get register_summary_pos_reports_path(register_session_id: @session.id)
    assert_redirected_to reports_register_summary_path(register_session_id: @session.id)
    follow_redirect!
    assert_response :success
    assert_match(/Register Summary/i, response.body)
    assert_match(/Sales &amp; Revenue/i, response.body)
    assert_match(/Drawer Reconciliation/i, response.body)
    assert_match(/Exceptions:/i, response.body)
    assert_match(/Print/i, response.body)
  end

  test "operational margin report redirects to canonical route" do
    get operational_margin_pos_reports_path(filter_type: "register_session", register_session_id: @session.id)
    assert_redirected_to reports_operational_margin_path(filter_type: "register_session", register_session_id: @session.id)
    follow_redirect!
    assert_response :success
    assert_match(/Operational Margin/i, response.body)
    assert_match(/Total COGS/i, response.body)
  end

  test "operational margin filter form submits to canonical report" do
    get reports_operational_margin_path(filter_type: "register_session", register_session_id: @session.id)
    assert_response :success
    assert_select "form.ss-filter-bar[action=?]", reports_operational_margin_path
  end
end
