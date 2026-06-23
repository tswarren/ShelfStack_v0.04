# frozen_string_literal: true

require "test_helper"

class Buybacks::CompleteSessionTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7c_permissions!(@user, store: @store)
    @customer = create_buyback_customer!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(
      sub_department: @sub,
      condition: @condition,
      selling_price_cents: 2000
    )
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Test Book")
    accept_buyback_line!(
      line: @line,
      session: @session,
      actor: @user,
      variant: @variant,
      condition: @condition,
      sub_department: @sub,
      payout_mode: "cash",
      offer_cents: 500
    )
    @register = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 10_000)
  end

  test "completes cash buyback with inventory and cash payout" do
    Buybacks::CompleteSession.call!(session: @session, actor: @user, register_session: @register)

    @session.reload
    assert @session.completed?
    assert_match(/-B\d{6}\z/, @session.buyback_number)
    assert_equal 500, @session.accepted_payout_cents
    assert @session.inventory_posting.present?
    assert_equal "used_buyback", @session.inventory_posting.posting_type
    assert @session.pos_cash_movement.present?
    assert_equal "paid_out", @session.pos_cash_movement.movement_type

    balance = InventoryBalance.find_by(store: @store, product_variant: @variant)
    assert_equal 1, balance.quantity_on_hand
  end

  test "completes trade credit buyback and issues identifier" do
    @session.update!(payout_mode: "trade_credit")
    @line.update!(outcome: "accepted_for_trade_credit")

    Buybacks::CompleteSession.call!(session: @session, actor: @user)

    @session.reload
    assert @session.completed?
    assert_equal "trade_credit", @session.stored_value_account.account_type
    assert @session.stored_value_ledger_entry.present?
    assert @session.stored_value_account.stored_value_identifiers.active_records.exists?
  end

  test "completes donation buyback with zero payout" do
    @session.update!(payout_mode: "no_value_donation")
    @line.update!(outcome: "accepted_as_donation", accepted_offer_cents: 0)

    Buybacks::CompleteSession.call!(session: @session, actor: @user)

    @session.reload
    assert @session.completed?
    assert_equal 0, @session.accepted_payout_cents
    assert_nil @session.pos_cash_movement
    assert_nil @session.stored_value_ledger_entry
    assert @session.inventory_posting.present?
  end
end
