# frozen_string_literal: true

require "test_helper"

class Buybacks::SessionsPrintProposalTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase7c_reference_data!
    @store = create_store!(
      name: "Corner Bookshop",
      address_line1: "100 Main St",
      city: "Ann Arbor",
      region_code: "MI",
      postal_code: "48104",
      phone: "555-0100"
    )
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_all_phase7c_permissions!(@user, store: @store)
    @customer = create_buyback_customer!(
      phone: "555-123-4567",
      email: "pat@example.com",
      customer_number: "CUST-000421"
    )
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(sub_department: @sub, condition: @condition, selling_price_cents: 2000)
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @offered_line = Buybacks::AddLine.call!(
      session: @session,
      actor: @user,
      title_snapshot: "The Great Gatsby",
      identifier_entered: "9780000000001"
    )
    @rejected_line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Dune")
    @reject_reason = BuybackRejectReason.active_records.first
    price_line!(@offered_line, cash: 150, trade: 240, resale: 600)
    price_line!(@rejected_line, cash: 100, trade: 150, resale: 800)
    Buybacks::RejectLine.call!(
      line: @rejected_line.reload,
      actor: @user,
      outcome: "rejected_by_store",
      reject_reason: @reject_reason
    )
    Buybacks::SaveProposal.call!(session: @session.reload, actor: @user)
    @session.reload
    login_user!(@user, workstation: @workstation)
  end

  test "print proposal renders structured document without app chrome" do
    get print_proposal_buybacks_session_path(@session)

    assert_response :success
    assert_includes response.body, "BUYBACK PROPOSAL &amp; SELLER ELECTION"
    assert_includes response.body, "Corner Bookshop"
    assert_includes response.body, @session.buyback_number
    assert_includes response.body, @user.display_name
    assert_includes response.body, "Buyback Seller"
    assert_includes response.body, "555-123-4567"
    assert_includes response.body, "CUST-000421"
    assert_includes response.body, "does not finalize payout"
    assert_includes response.body, "Seller Verification"
    assert_includes response.body, "Items Offered for Purchase"
    assert_includes response.body, "The Great Gatsby"
    assert_includes response.body, "9780000000001"
    assert_includes response.body, "Items Not Accepted for Purchase"
    assert_includes response.body, "Dune"
    assert_includes response.body, @reject_reason.name
    assert_includes response.body, "Proposal Totals"
    assert_includes response.body, "Seller Election"
    assert_includes response.body, "Unaccepted Items"
    assert_includes response.body, "Acknowledgment"
    assert_includes response.body, "For Internal Use Only"
    assert_not_includes response.body, "ss-nav"
    assert_not_includes response.body, "ss-header"
    assert @session.reload.proposal_printed_at.present?
    assert AuditEvent.exists?(event_name: "buyback.proposal.printed", auditable: @session)
  end

  test "draft session cannot print proposal" do
    draft_session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)

    get print_proposal_buybacks_session_path(draft_session)

    assert_redirected_to buybacks_session_path(draft_session)
    assert_match(/after the proposal is saved/i, flash[:alert].to_s)
    assert_not AuditEvent.exists?(event_name: "buyback.proposal.printed", auditable: draft_session)
  end

  test "completed session can reprint proposal" do
    Buybacks::OpenCustomerDecision.call!(session: @session, actor: @user) unless @session.decision?
    Buybacks::RecordCustomerDecision.call!(
      line: @offered_line.reload,
      session: @session,
      actor: @user,
      outcome: "accepted_by_customer"
    )
    @session.update!(payout_mode: "cash")
    register = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 10_000)
    Buybacks::CompleteSession.call!(session: @session.reload, actor: @user, register_session: register)

    get print_proposal_buybacks_session_path(@session.reload)

    assert_response :success
    assert_includes response.body, @session.buyback_number
  end

  test "print proposal requires permission" do
    delete logout_path
    viewer = create_user!(username: "proposal_viewer", pin: "1234")
    grant_permission!(viewer, "buybacks.view", store: @store)
    login_user!(viewer, workstation: @workstation)

    get print_proposal_buybacks_session_path(@session)

    assert_response :redirect
    assert_match(/not authorized/i, flash[:alert].to_s)
  end

  private

  def price_line!(line, cash:, trade:, resale:)
    line.update!(
      product: @variant.product,
      catalog_item: @variant.product.catalog_item,
      product_variant: @variant,
      list_price_cents: @variant.product.list_price_cents
    )
    Buybacks::UpdateProposalLine.call!(
      line: line,
      session: @session,
      actor: @user,
      product_condition: @condition,
      sub_department: @sub,
      proposed_resale_price_cents: resale,
      proposed_cash_offer_cents: cash,
      proposed_trade_credit_offer_cents: trade,
      resale_override_reason: "Test setup",
      cash_override_reason: "Test setup",
      trade_credit_override_reason: "Test setup"
    )
  end
end
