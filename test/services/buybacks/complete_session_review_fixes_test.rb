# frozen_string_literal: true

require "test_helper"

class Buybacks::CompleteSessionReviewFixesTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7c_permissions!(@user, store: @store)
    @customer = create_buyback_customer!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(sub_department: @sub, condition: @condition, selling_price_cents: 2000)
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @register = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 10_000)
  end

  test "donated line in cash session posts zero cost and is excluded from cash payout" do
    accepted_line = add_priced_line!(title: "Accepted Book", cash: 500, trade: 600)
    donated_line = add_priced_line!(title: "Donated Book", cash: 400, trade: 450)

    finalize_proposal_and_decisions!(
      accepted_line => "accepted_by_customer",
      donated_line => "donated_by_customer"
    )
    @session.update!(payout_mode: "cash")

    Buybacks::CompleteSession.call!(session: @session.reload, actor: @user, register_session: @register)

    donated_line.reload
    accepted_line.reload
    assert_equal 0, donated_line.accepted_offer_cents
    assert_equal 500, accepted_line.accepted_offer_cents
    assert_equal 500, @session.reload.accepted_payout_cents
    assert_equal 500, @session.pos_cash_movement.amount_cents

    donated_entry = donated_line.inventory_ledger_entry
    assert_equal 0, donated_entry.unit_cost_cents
    assert_equal "no_value_donation", donated_entry.cost_source
  end

  test "no_value_donation rejects accepted_by_customer posting lines" do
    line = add_priced_line!(title: "Accepted Book", cash: 500, trade: 600)
    finalize_proposal_and_decisions!(line => "accepted_by_customer")
    @session.update!(payout_mode: "no_value_donation")

    error = assert_raises(Buybacks::CompleteSession::Error) do
      Buybacks::CompleteSession.call!(session: @session.reload, actor: @user)
    end
    assert_match(/donated by the customer/i, error.message)
  end

  test "store-rejected priced line does not block completion" do
    accepted_line = add_priced_line!(title: "Accepted Book", cash: 500, trade: 600)
    rejected_line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Rejected Book")
    rejected_line.update!(product: @variant.product, catalog_item: @variant.product.catalog_item, list_price_cents: 2000)
    Buybacks::UpdateProposalLine.call!(
      line: rejected_line,
      session: @session,
      actor: @user,
      product_condition: @condition,
      sub_department: @sub,
      proposed_resale_price_cents: 2000,
      proposed_cash_offer_cents: 100,
      proposed_trade_credit_offer_cents: 150,
      resale_override_reason: "Test setup",
      cash_override_reason: "Test setup",
      trade_credit_override_reason: "Test setup"
    )
    Buybacks::SaveProposal.call!(session: @session.reload, actor: @user)
    Buybacks::OpenCustomerDecision.call!(session: @session.reload, actor: @user)
    Buybacks::RecordCustomerDecision.call!(line: accepted_line.reload, session: @session, actor: @user, outcome: "accepted_by_customer")
    Buybacks::RejectLine.call!(line: rejected_line.reload, actor: @user, outcome: "rejected_by_store", reject_reason: BuybackRejectReason.active_records.first)
    @session.update!(payout_mode: "cash")

    assert_nothing_raised do
      Buybacks::CompleteSession.call!(session: @session.reload, actor: @user, register_session: @register)
    end
  end

  test "updating decided line clears customer decision" do
    line = add_priced_line!(title: "Decision Book", cash: 500, trade: 600)
    finalize_proposal_and_decisions!(line => "accepted_by_customer")
    assert_equal "accepted_by_customer", line.reload.outcome

    Buybacks::UpdateProposalLine.call!(
      line: line,
      session: @session.reload,
      actor: @user,
      product_condition: @condition,
      sub_department: @sub,
      proposed_resale_price_cents: 2100,
      proposed_cash_offer_cents: 500,
      proposed_trade_credit_offer_cents: 600,
      resale_override_reason: "Condition repriced",
      cash_override_reason: "Test setup",
      trade_credit_override_reason: "Test setup"
    )

    line.reload
    assert_nil line.outcome
    assert_nil line.customer_decision_at
    assert_equal "priced", line.status
  end

  test "manual proposed value edit requires override permission and reason" do
    line = add_priced_line!(title: "Override Book", cash: 500, trade: 600)
    limited_user = create_user!(username: "limited_buyback")
    grant_permission!(limited_user, "buybacks.update", store: @store)

    error = assert_raises(Buybacks::UpdateProposalLine::Error) do
      Buybacks::UpdateProposalLine.call!(
        line: line,
        session: @session,
        actor: limited_user,
        product_condition: @condition,
        sub_department: @sub,
        proposed_resale_price_cents: 2500,
        proposed_cash_offer_cents: 500,
        proposed_trade_credit_offer_cents: 600,
        resale_override_reason: "Staff adjustment"
      )
    end
    assert_match(/override permission/i, error.message)
  end

  test "accepted snapshots roll back when cash payout fails inside transaction" do
    line = add_priced_line!(title: "Rollback Book", cash: 500, trade: 600)
    finalize_proposal_and_decisions!(line => "accepted_by_customer")
    @session.update!(payout_mode: "cash")

    assert_raises(Buybacks::CompleteSession::Error) do
      Buybacks::CompleteSession.call!(session: @session.reload, actor: @user, register_session: nil)
    end

    line.reload
    assert_nil line.accepted_offer_cents
    assert_nil line.accepted_resale_price_cents
    assert @session.reload.decision?
  end

  private

  def add_priced_line!(title:, cash:, trade:)
    line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: title)
    line.update!(product: @variant.product, catalog_item: @variant.product.catalog_item, list_price_cents: 2000)
    Buybacks::UpdateProposalLine.call!(
      line: line,
      session: @session,
      actor: @user,
      product_condition: @condition,
      sub_department: @sub,
      proposed_resale_price_cents: 2000,
      proposed_cash_offer_cents: cash,
      proposed_trade_credit_offer_cents: trade,
      resale_override_reason: "Test setup",
      cash_override_reason: "Test setup",
      trade_credit_override_reason: "Test setup"
    )
    line
  end

  def finalize_proposal_and_decisions!(decisions)
    Buybacks::SaveProposal.call!(session: @session.reload, actor: @user) unless @session.buyback_number.present?
    Buybacks::OpenCustomerDecision.call!(session: @session.reload, actor: @user) unless @session.decision?
    decisions.each do |line, outcome|
      Buybacks::RecordCustomerDecision.call!(line: line.reload, session: @session.reload, actor: @user, outcome: outcome)
    end
  end
end
