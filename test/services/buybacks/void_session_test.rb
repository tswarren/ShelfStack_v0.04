# frozen_string_literal: true

require "test_helper"

class Buybacks::VoidSessionTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_all_phase7c_permissions!(@user, store: @store)
    @customer = create_buyback_customer!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(sub_department: @sub, condition: @condition)
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Void Book")
    accept_buyback_line!(line: @line, session: @session, actor: @user, variant: @variant, condition: @condition, sub_department: @sub)
    @register = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 10_000)
    Buybacks::CompleteSession.call!(session: @session, actor: @user, register_session: @register)
    @session.reload
  end

  test "void reverses trade credit with buyback void source" do
    trade_session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    line = Buybacks::AddLine.call!(session: trade_session, actor: @user, title_snapshot: "Trade Credit Void")
    trade_session.update!(payout_mode: "trade_credit")
    accept_buyback_line!(
      line: line,
      session: trade_session,
      actor: @user,
      variant: @variant,
      condition: @condition,
      sub_department: @sub,
      payout_mode: "trade_credit"
    )
    Buybacks::CompleteSession.call!(session: trade_session, actor: @user)

    buyback_void = Buybacks::VoidSession.call!(
      session: trade_session.reload,
      actor: @user,
      void_reason: "Customer returned items"
    )

    reversal = buyback_void.void_stored_value_ledger_entry
    assert reversal.present?
    assert_equal buyback_void, reversal.source
  end

  test "void reverses inventory and cash with authorization" do
    @register.reload
    auth = grant_void_buyback_authorization!(register_session: @register, requested_by: @user, manager: @user)

    buyback_void = Buybacks::VoidSession.call!(
      session: @session,
      actor: @user,
      register_session: @register,
      void_reason: "Customer returned items",
      pos_authorization: auth
    )

    @session.reload
    assert @session.voided?
    assert_equal "buyback_void", buyback_void.inventory_posting.posting_type
    assert_equal "BuybackVoid", buyback_void.inventory_posting.source_type
    assert buyback_void.void_cash_movement.present?
    assert_equal "paid_in", buyback_void.void_cash_movement.movement_type

    balance = InventoryBalance.find_by(store: @store, product_variant: @variant)
    assert_equal 0, balance.quantity_on_hand
  end
end
