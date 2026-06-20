# frozen_string_literal: true

require "test_helper"

class PosHomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "home_cashier")
    grant_all_phase6_permissions!(@cashier, store: @store)

    @variant = create_product_variant!(sku: "HOME-SKU-001", selling_price_cents: 1200)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)

    login_user!(@cashier, workstation: @workstation)
  end

  test "open register renders action buttons session summary and queue tables" do
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier)

    get pos_root_path
    assert_response :success

    assert_select "h1", text: "Point of Sale"
    assert_match "Manage Session", response.body
    assert_match "Cash In/Out", response.body
    assert_match "Reports", response.body
    assert_match(/New Transaction|Continue/, response.body)
    assert_select ".ss-pos-panel__title", text: "Session Summary"
    assert_select "a[href=?]", register_summary_pos_reports_path(register_session_id: @register_session.id), text: "Register Summary"
    assert_select "a[href=?]", drawer_pos_reports_path, text: "Session history"
    assert_select ".ss-pos-panel__title", text: "Suspended Transactions"
    assert_select ".ss-pos-panel__title", text: "Draft Queue"
    assert_select "td.ss-pos-home__empty", text: "None"
  end

  test "closed register renders minimal actions and draft panel only" do
    get pos_root_path
    assert_response :success

    assert_match "Open Register", response.body
    assert_match "Sessions (History)", response.body
    assert_match "Reports", response.body
    assert_no_match "Session Summary", response.body
    assert_select ".ss-pos-panel__title", text: "Draft Queue"
    assert_no_match "Suspended Transactions", response.body
  end

  test "queue tables render draft and suspended rows" do
    open_register_session!(store: @store, workstation: @workstation, user: @cashier)

    draft = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [{ product_variant: @variant, quantity: 1, unit_price_cents: 1200, extended_price_cents: 1200 }]
    )

    suspended = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: { status: "suspended", suspended_at: Time.current },
      lines: [{ product_variant: @variant, quantity: 1, unit_price_cents: 1200, extended_price_cents: 1200 }]
    )

    get pos_root_path
    assert_response :success
    assert_match "##{draft.id}", response.body
    assert_match "##{suspended.id}", response.body
    assert_select "a[href=?]", edit_pos_transaction_path(draft), text: "Continue"
    assert_select "a[href=?]", resume_pos_transaction_path(suspended), text: "Resume"
  end
end
