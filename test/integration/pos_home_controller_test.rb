# frozen_string_literal: true

require "test_helper"

class PosHomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "home_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, login: true, inventory_qty: 0)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @variant = @ctx[:variant]
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 5)
  end

  test "open register renders action buttons session summary and queue tables" do
    @register_session = @ctx[:register_session]

    get pos_root_path
    assert_response :success

    assert_select "h1", text: "Point of Sale"
    assert_match "Manage Session", response.body
    assert_match "Cash In/Out", response.body
    assert_match "Reports", response.body
    assert_select "button", text: "New sale"
    assert_select ".ss-pos-panel__title", text: "Session Summary"
    assert_select "a[href=?]", register_summary_pos_reports_path(register_session_id: @register_session.id), text: "Register Summary"
    assert_select "a[href=?]", drawer_pos_reports_path, text: "Session history"
    assert_select ".ss-pos-panel__title", text: "Suspended Transactions"
    assert_select ".ss-pos-panel__title", text: "Draft Queue"
    assert_select "td.ss-pos-home__empty", text: "None"
  end

  test "closed register renders minimal actions and draft panel only" do
    PosRegisterSession.where(workstation: @workstation).find_each do |session|
      Pos::RegisterSessionLifecycle.close!(
        session: session,
        closed_by_user: @cashier,
        expected_closing_cash_cents: 0,
        counted_closing_cash_cents: 0,
        force: false
      )
    end

    get pos_root_path
    assert_response :success

    assert_match "Open Register", response.body
    assert_match "Sessions (History)", response.body
    assert_match "Reports", response.body
    assert_no_match "Session Summary", response.body
    assert_select ".ss-pos-panel__title", text: "Draft Queue"
    assert_no_match "Suspended Transactions", response.body
  end

  test "queue tables render draft and suspended rows when landing shows conflict picker" do
    @register_session = @ctx[:register_session]

    legacy_draft = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1200, extended_price_cents: 1200 } ]
    )

    suspended = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: { status: "suspended", suspended_at: Time.current },
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1200, extended_price_cents: 1200 } ]
    )

    get pos_root_path
    assert_response :success
    assert_match "Older draft needs review", response.body
    assert_match "##{legacy_draft.id}", response.body
    assert_match "##{suspended.id}", response.body
    assert_select "a[href=?]", resume_pos_transaction_path(suspended), text: "Resume"
  end
end
