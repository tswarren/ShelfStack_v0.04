# frozen_string_literal: true

require "test_helper"

class Buybacks::SessionWorkflowPresenterTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7c_permissions!(@user, store: @store)
    @customer = create_buyback_customer!
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
  end

  test "draft with no lines suggests scan or add item" do
    workflow = build_workflow

    assert_equal "Scan or add item", workflow.next_action.label
    assert_equal :intake, workflow.current_step_key
  end

  test "draft with priced lines enables save proposal next action" do
    add_priced_line!
    workflow = build_workflow

    assert workflow.action_state(:save_proposal).enabled
    assert_equal "Save proposal", workflow.next_action.label
  end

  test "decision stage exposes decision totals footer text" do
    line = add_priced_line!
    finalize_to_decision!(line)
    workflow = build_workflow(status: "decision", decision_totals: decision_totals)

    assert_includes workflow.footer_summary_text, "Accepted"
    assert_equal :customer_decision, workflow.current_step_key
  end

  test "complete action disabled when payout mode missing" do
    line = add_priced_line!
    finalize_to_decision!(line)
    Buybacks::RecordCustomerDecision.call!(line: line.reload, session: @session.reload, actor: @user, outcome: "accepted_by_customer")
    workflow = build_workflow(status: "decision", decision_totals: decision_totals)

    state = workflow.action_state(:complete)
    assert_not state.enabled
    assert_match(/payout method/i, state.reason)
  end

  test "line workflow state maps pending to needs_match" do
    line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Pending")
    workflow = build_workflow

    assert_equal :needs_match, workflow.line_workflow_state(line)
    assert_equal "Needs match", buyback_line_workflow_label(line, workflow: workflow)
  end

  test "batch accept disabled when repriced lines exist" do
    line = add_priced_line!
    finalize_to_decision!(line)
    line.reload.update!(status: "priced", outcome: nil, customer_decision_at: nil)
    workflow = build_workflow(status: "decision", decision_totals: decision_totals)

    assert workflow.repriced_lines_blocking_batch?
    assert_not workflow.action_state(:accept_all).enabled
  end

  private

  def build_workflow(status: @session.status, decision_totals: nil)
    @session.update!(status: status) if status != @session.status
    lines = @session.buyback_lines.order(:line_number)
    Buybacks::SessionWorkflowPresenter.new(
      session: @session.reload,
      lines: lines,
      proposal: (@session.quoted? || @session.decision?) ? Buybacks::ProposalBuilder.build(@session) : nil,
      decision_totals: decision_totals,
      seller_requirements: Buybacks::SellerRequirements.check(customer: @customer),
      register_session: nil
    )
  end

  def decision_totals
    Buybacks::DecisionTotalsBuilder.build(@session.reload)
  end

  def add_priced_line!
    variant = create_product_variant!(sub_department: @sub, condition: @condition, selling_price_cents: 2000)
    line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Workflow Book")
    line.update!(product: variant.product, catalog_item: variant.product.catalog_item)
    Buybacks::UpdateProposalLine.call!(
      line: line,
      session: @session,
      actor: @user,
      product_condition: @condition,
      sub_department: @sub,
      proposed_resale_price_cents: 2000,
      proposed_cash_offer_cents: 500,
      proposed_trade_credit_offer_cents: 600,
      resale_override_reason: "Test setup",
      cash_override_reason: "Test setup",
      trade_credit_override_reason: "Test setup"
    )
    line
  end

  def finalize_to_decision!(line)
    Buybacks::SaveProposal.call!(session: @session.reload, actor: @user)
    Buybacks::OpenCustomerDecision.call!(session: @session.reload, actor: @user)
    line.reload.update!(status: "offered")
  end

  include BuybacksHelper
end
