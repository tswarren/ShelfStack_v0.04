# frozen_string_literal: true

require "test_helper"

class Buybacks::PostVoidInventoryTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7c_permissions!(@user, store: @store)
    @customer = create_buyback_customer!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(sub_department: @sub, condition: @condition)
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @line_one = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Copy One")
    @line_two = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Copy Two")
    accept_buyback_line!(line: @line_one, session: @session, actor: @user, variant: @variant, condition: @condition, sub_department: @sub, save_proposal: false, record_decision: false)
    accept_buyback_line!(line: @line_two, session: @session, actor: @user, variant: @variant, condition: @condition, sub_department: @sub, save_proposal: false, record_decision: false)
    Buybacks::SaveProposal.call!(session: @session, actor: @user)
    Buybacks::OpenCustomerDecision.call!(session: @session.reload, actor: @user)
    Buybacks::RecordCustomerDecision.call!(line: @line_one.reload, session: @session, actor: @user, outcome: "accepted_by_customer")
    Buybacks::RecordCustomerDecision.call!(line: @line_two.reload, session: @session, actor: @user, outcome: "accepted_by_customer")
    @register = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 10_000)
    Buybacks::CompleteSession.call!(session: @session, actor: @user, register_session: @register)
    @session.reload
  end

  test "maps void ledger entries by original line number when variant is shared" do
    buyback_void = BuybackVoid.create!(
      buyback_session: @session,
      store: @store,
      workstation: @workstation,
      voided_at: Time.current,
      voided_by_user: @user,
      void_reason: "Duplicate variant mapping test"
    )

    Buybacks::PostVoidInventory.call(buyback_void:, posted_by_user: @user)

    @line_one.reload
    @line_two.reload
    assert @line_one.void_inventory_ledger_entry.present?
    assert @line_two.void_inventory_ledger_entry.present?
    assert_not_equal @line_one.void_inventory_ledger_entry_id, @line_two.void_inventory_ledger_entry_id
    assert_equal @line_one.inventory_ledger_entry.line_number, @line_one.void_inventory_ledger_entry.line_number
    assert_equal @line_two.inventory_ledger_entry.line_number, @line_two.void_inventory_ledger_entry.line_number
  end
end
