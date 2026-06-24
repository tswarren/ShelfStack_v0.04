# frozen_string_literal: true

require "test_helper"

class Buybacks::ProposalBuilderTest < ActiveSupport::TestCase
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
    @offered_line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Offered Book", identifier_entered: "9780000000001")
    @rejected_line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Rejected Book")
  end

  test "groups offered and store-rejected lines with totals from offered lines only" do
    price_line!(@offered_line, cash: 500, trade: 600, resale: 2000)
    price_line!(@rejected_line, cash: 100, trade: 150, resale: 800)
    reject_reason = BuybackRejectReason.active_records.first
    Buybacks::RejectLine.call!(
      line: @rejected_line.reload,
      actor: @user,
      outcome: "rejected_by_store",
      reject_reason: reject_reason
    )

    proposal = Buybacks::ProposalBuilder.build(@session.reload)

    assert_equal [ @offered_line.id ], proposal.offered_lines.map(&:id)
    assert_equal [ @rejected_line.id ], proposal.not_accepted_lines.map(&:id)
    assert_equal proposal.offered_lines, proposal.lines
    assert_equal 2000, proposal.totals[:resale_cents]
    assert_equal 500, proposal.totals[:cash_offer_cents]
    assert_equal 600, proposal.totals[:trade_credit_offer_cents]
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
