# frozen_string_literal: true

require "test_helper"

class PosWorkspaceHeaderTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "pos_header_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, login: true, inventory_qty: 0)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
  end

  test "idle workspace renders shared header with actions menu" do
    get pos_root_path

    assert_response :success
    assert_select ".ss-pos-workspace-header"
    assert_select ".ss-pos-workspace-header__brand", text: "Point of Sale"
    assert_select ".ss-pos-workspace-header__actions summary", text: "Actions"
    assert_select "button[data-action*='openCashIn']"
  end

  test "transaction edit renders header with transaction context" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )

    get edit_pos_transaction_path(transaction)

    assert_response :success
    assert_select ".ss-pos-workspace-header__transaction", text: /##{transaction.id}/
  end

  test "closed register enables balance action and disables cash in" do
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
    assert_select ".ss-pos-workspace-header__register-status", text: "Register closed"
    assert_select "button[data-action*='showBalanceModal']"
    assert_includes response.body, "Cash In"
    assert_includes response.body, Pos::CommandRegistry::NO_REGISTER_SESSION_MESSAGE
  end
end
