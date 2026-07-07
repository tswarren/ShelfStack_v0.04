# frozen_string_literal: true

require "test_helper"

class PosUxContractTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "pos_ux_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, login: true, inventory_qty: 0)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
    @variant = @ctx[:variant]
  end

  test "pos open workspace quick actions use contract buttons" do
    get pos_root_path

    assert_response :success
    assert_select "button.ss-btn-secondary.ss-btn--small", text: "Open Ring"
    assert_select "button.ss-btn-secondary.ss-btn--small", text: "Gift Card"
  end

  test "pos closed home action grid uses contract buttons" do
    PosRegisterSession.where(workstation: @workstation).find_each do |session|
      Pos::RegisterSessionLifecycle.close!(
        session: session,
        closed_by_user: @cashier,
        expected_closing_cash_cents: session.expected_closing_cash_cents || 0,
        counted_closing_cash_cents: session.counted_closing_cash_cents || 0,
        force: false
      )
    end

    get pos_root_path

    assert_response :success
    assert_select ".ss-pos-action-grid a.ss-btn-primary", text: "Open Register"
    assert_select ".ss-pos-action-grid a.ss-btn-secondary", text: "Reports"
  end

  test "register session new uses contract form footer" do
    PosRegisterSession.where(workstation: @workstation).find_each do |session|
      Pos::RegisterSessionLifecycle.close!(
        session: session,
        closed_by_user: @cashier,
        expected_closing_cash_cents: session.expected_closing_cash_cents || 0,
        counted_closing_cash_cents: session.counted_closing_cash_cents || 0,
        force: false
      )
    end

    get new_pos_register_session_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Open Register Session"
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Open register"
    assert_select "footer.ss-form-actions a.ss-btn-tertiary", text: "Cancel"
  end

  test "completed workspace uses contract footer actions" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }
      ]
    )
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    complete_pos_sale!(
      transaction: transaction.reload,
      user: @cashier,
      register_session: @register_session
    )

    get completed_pos_transaction_path(transaction.reload)

    assert_response :success
    assert_select ".ss-pos-completed-workspace__footer a.ss-btn-primary", text: "New Sale"
    assert_select ".ss-pos-completed-workspace__footer a.ss-btn-tertiary", text: "View Summary"
  end
end
