# frozen_string_literal: true

require "test_helper"

class Buybacks::FreshReviewFixesTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7c_permissions!(@user, store: @store)
    @customer = create_buyback_customer!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @register = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 10_000)
  end

  test "proposal pricing does not mutate existing variant selling price when stock on hand" do
    variant = create_product_variant!(
      sub_department: @sub,
      condition: @condition,
      selling_price_cents: 1500,
      product: create_product!(list_price_cents: 3000)
    )
    InventoryBalance.create!(
      store: @store,
      product_variant: variant,
      quantity_on_hand: 2,
      quantity_available: 2,
      inventory_cost_value_cents: 0,
      inventory_retail_value_cents: 0
    )
    line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Stocked Book")
    line.update!(product: variant.product, catalog_item: variant.product.catalog_item)

    Buybacks::UpdateProposalLine.call!(
      line: line,
      session: @session,
      actor: @user,
      product_condition: @condition,
      sub_department: @sub,
      proposed_resale_price_cents: 2200,
      proposed_cash_offer_cents: 500,
      proposed_trade_credit_offer_cents: 600,
      resale_override_reason: "Test setup",
      cash_override_reason: "Test setup",
      trade_credit_override_reason: "Test setup"
    )

    assert_equal 1500, variant.reload.selling_price_cents
    assert_equal 2200, line.reload.proposed_resale_price_cents
  end

  test "proposal pricing updates existing variant selling price when no stock on hand" do
    variant = create_product_variant!(
      sub_department: @sub,
      condition: @condition,
      selling_price_cents: 1500,
      product: create_product!(list_price_cents: 3000)
    )
    line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "No Stock Book")
    line.update!(product: variant.product, catalog_item: variant.product.catalog_item)

    Buybacks::UpdateProposalLine.call!(
      line: line,
      session: @session,
      actor: @user,
      product_condition: @condition,
      sub_department: @sub,
      proposed_resale_price_cents: 2200,
      proposed_cash_offer_cents: 500,
      proposed_trade_credit_offer_cents: 600,
      resale_override_reason: "Test setup",
      cash_override_reason: "Test setup",
      trade_credit_override_reason: "Test setup"
    )

    assert_equal 2200, variant.reload.selling_price_cents
  end

  test "completion does not update variant selling price when stock on hand" do
    variant = create_product_variant!(
      sub_department: @sub,
      condition: @condition,
      selling_price_cents: 1500,
      product: create_product!(list_price_cents: 3000)
    )
    InventoryBalance.create!(
      store: @store,
      product_variant: variant,
      quantity_on_hand: 1,
      quantity_available: 1,
      inventory_cost_value_cents: 0,
      inventory_retail_value_cents: 0
    )
    line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Completion Stock Book")
    accept_buyback_line!(
      line: line,
      session: @session,
      actor: @user,
      variant: variant,
      condition: @condition,
      sub_department: @sub,
      resale_price_cents: 2400
    )

    Buybacks::CompleteSession.call!(session: @session.reload, actor: @user, register_session: @register)

    assert_equal 1500, variant.reload.selling_price_cents
  end

  test "lines can only be added while session is draft" do
    @session.update!(status: "quoted")

    error = assert_raises(ArgumentError) do
      Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Late line")
    end
    assert_match(/draft/i, error.message)
  end

  test "completion blocks pending or resolved lines" do
    accepted_line = add_priced_line!(title: "Accepted", cash: 500, trade: 600)
    finalize_proposal_and_decisions!(accepted_line => "accepted_by_customer")
    @session.buyback_lines.create!(
      line_number: @session.buyback_lines.maximum(:line_number).to_i + 1,
      status: "pending",
      title_snapshot: "Orphan pending"
    )
    @session.update!(payout_mode: "cash", status: "decision")

    error = assert_raises(Buybacks::CompleteSession::Error) do
      Buybacks::CompleteSession.call!(session: @session.reload, actor: @user, register_session: @register)
    end
    assert_match(/resolved, priced, and decided/i, error.message)
  end

  test "batch accept only processes offered lines and rejects repriced lines" do
    offered = add_priced_line!(title: "Offered", cash: 500, trade: 600)
    Buybacks::SaveProposal.call!(session: @session.reload, actor: @user)
    Buybacks::OpenCustomerDecision.call!(session: @session.reload, actor: @user)
    offered.reload.update!(status: "priced", outcome: nil, customer_decision_at: nil)

    error = assert_raises(Buybacks::RecordCustomerDecision::Error) do
      Buybacks::AcceptAllLines.call!(session: @session.reload, actor: @user)
    end
    assert_match(/saved back into the proposal/i, error.message)
  end

  test "re-saving unchanged override does not require reason again" do
    line = add_priced_line!(title: "Override Book", cash: 700, trade: 800)

    assert_nothing_raised do
      Buybacks::UpdateProposalLine.call!(
        line: line,
        session: @session,
        actor: @user,
        product_condition: @condition,
        sub_department: @sub,
        proposed_resale_price_cents: 2000,
        proposed_cash_offer_cents: 700,
        proposed_trade_credit_offer_cents: 800
      )
    end

    line.reload
    assert line.cash_offer_overridden?
    assert_equal "Test setup", line.cash_offer_override_reason
  end

  test "reject line enforces session editability and posted guard" do
    line = add_priced_line!(title: "Reject Book", cash: 500, trade: 600)
    @session.update!(status: "completed")
    line.update!(status: "posted")

    error = assert_raises(Buybacks::RejectLine::Error) do
      Buybacks::RejectLine.call!(
        line: line,
        actor: @user,
        outcome: "rejected_by_store",
        reject_reason: BuybackRejectReason.active_records.first
      )
    end
    assert_match(/not editable|cannot be changed/i, error.message)
  end

  test "reject line rejects non-rejection outcomes" do
    line = add_priced_line!(title: "Reject Outcome Book", cash: 500, trade: 600)

    error = assert_raises(Buybacks::RejectLine::Error) do
      Buybacks::RejectLine.call!(
        line: line,
        actor: @user,
        outcome: "accepted_by_customer"
      )
    end
    assert_match(/rejection outcome/i, error.message)
  end

  test "variant created by current session allows price update when stock exists" do
    variant = create_product_variant!(
      sub_department: @sub,
      condition: @condition,
      selling_price_cents: 1500,
      product: create_product!(list_price_cents: 3000),
      created_from_buyback_session: @session
    )
    InventoryBalance.create!(
      store: @store,
      product_variant: variant,
      quantity_on_hand: 1,
      quantity_available: 1,
      inventory_cost_value_cents: 0,
      inventory_retail_value_cents: 0
    )
    line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Session Variant")
    line.update!(product: variant.product, catalog_item: variant.product.catalog_item)

    Buybacks::UpdateProposalLine.call!(
      line: line,
      session: @session,
      actor: @user,
      product_condition: @condition,
      sub_department: @sub,
      proposed_resale_price_cents: 2200,
      proposed_cash_offer_cents: 500,
      proposed_trade_credit_offer_cents: 600,
      resale_override_reason: "Test setup",
      cash_override_reason: "Test setup",
      trade_credit_override_reason: "Test setup"
    )

    assert_equal 2200, variant.reload.selling_price_cents
  end

  private

  def add_priced_line!(title:, cash:, trade:)
    variant = create_product_variant!(
      sub_department: @sub,
      condition: @condition,
      selling_price_cents: 2000,
      product: create_product!(list_price_cents: 3000)
    )
    line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: title)
    line.update!(product: variant.product, catalog_item: variant.product.catalog_item)
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
