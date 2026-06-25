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

  test "summary report renders for register session filter" do
    get summary_pos_reports_path(filter_type: "register_session", register_session_id: @session.id)
    assert_response :success
    assert_match(/Sales &amp; Revenue/i, response.body)
    assert_match(/Gross Sales/i, response.body)
    assert_match(/By clerk/i, response.body)
    assert_match(/Drawer reconciliation/i, response.body)
    assert_match(/Print/i, response.body)
  end

  test "summary report exports csv" do
    get summary_pos_reports_path(
      filter_type: "register_session",
      register_session_id: @session.id,
      format: :csv
    )
    assert_response :success
    assert_match "Gross Sales", response.body
    assert_match "Clerk", response.body
  end

  test "register summary report renders for session" do
    get register_summary_pos_reports_path(register_session_id: @session.id)
    assert_response :success
    assert_match(/Sales &amp; Register Summary/i, response.body)
    assert_match(/Sales &amp; Revenue/i, response.body)
    assert_match(/Drawer Reconciliation/i, response.body)
    assert_match(/Exceptions:/i, response.body)
    assert_match(/Print/i, response.body)
  end

  test "operational margin report renders for register session filter" do
    get operational_margin_pos_reports_path(filter_type: "register_session", register_session_id: @session.id)
    assert_response :success
    assert_match(/Operational Margin/i, response.body)
    assert_match(/Actual gross margin/i, response.body)
  end

  test "operational margin filter form submits to operational margin report" do
    get operational_margin_pos_reports_path(filter_type: "register_session", register_session_id: @session.id)
    assert_response :success
    assert_select "form.ss-pos-report-filter__form[action=?]", operational_margin_pos_reports_path
  end
end
