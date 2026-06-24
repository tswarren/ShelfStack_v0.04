# frozen_string_literal: true

require "test_helper"

class Buybacks::TradeCreditIssuanceSlipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_all_phase7c_permissions!(@user, store: @store)
    @customer = create_buyback_customer!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(sub_department: @sub, condition: @condition, selling_price_cents: 2000)
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Trade Credit Book")
    accept_buyback_line!(
      line: @line,
      session: @session,
      actor: @user,
      variant: @variant,
      condition: @condition,
      sub_department: @sub,
      payout_mode: "trade_credit"
    )
    @session.update!(payout_mode: "trade_credit")
    Buybacks::CompleteSession.call!(session: @session, actor: @user)
    @session.reload
    login_user!(@user, workstation: @workstation)
  end

  test "show displays full trade credit identifier and records initial print audit" do
    get trade_credit_slip_buybacks_session_path(@session)

    assert_response :success
    identifier = @session.stored_value_account.stored_value_identifiers.active_records.first
    formatted = StoredValue::IdentifierCodec.format_display(
      StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)
    )
    assert_includes response.body, formatted
    assert AuditEvent.exists?(event_name: "buyback.trade_credit_slip.printed", auditable: @session)
  end

  test "receipt masks trade credit identifier" do
    get receipt_buybacks_session_path(@session)

    assert_response :success
    identifier = @session.stored_value_account.stored_value_identifiers.active_records.first
    formatted = StoredValue::IdentifierCodec.format_display(
      StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)
    )
    assert_includes response.body, identifier.display_value_masked
    assert_not_includes response.body, formatted
  end

  test "print requires authorization and records reprint audit" do
    post print_trade_credit_slip_buybacks_session_path(@session)

    assert_redirected_to trade_credit_slip_buybacks_session_path(@session)
    assert AuditEvent.exists?(event_name: "buyback.trade_credit_slip.reprinted", auditable: @session)
  end
end
