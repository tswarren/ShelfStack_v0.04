# frozen_string_literal: true

require "test_helper"

class Buybacks::SaveProposalTest < ActiveSupport::TestCase
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
    @line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Proposal Book")
  end

  test "assigns buyback number and marks session quoted" do
    @line.update!(
      product: @variant.product,
      catalog_item: @variant.product.catalog_item,
      list_price_cents: @variant.product.list_price_cents
    )

    Buybacks::UpdateProposalLine.call!(
      line: @line,
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

    Buybacks::SaveProposal.call!(session: @session, actor: @user)

    @session.reload
    assert @session.quoted?
    assert_match(/-B\d{6}\z/, @session.buyback_number)
    assert @session.proposal_saved_at.present?
    assert_equal "offered", @line.reload.status
  end

  test "rejects unresolved lines" do
    assert_raises(Buybacks::SaveProposal::Error) do
      Buybacks::SaveProposal.call!(session: @session, actor: @user)
    end
  end
end
