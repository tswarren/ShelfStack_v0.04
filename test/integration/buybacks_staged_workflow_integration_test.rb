# frozen_string_literal: true

require "test_helper"

class BuybacksStagedWorkflowIntegrationTest < ActionDispatch::IntegrationTest
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
    login_user!(@user, workstation: @workstation)
  end

  test "full staged buyback workflow from intake through completion" do
    post buybacks_sessions_path, params: { customer_id: @customer.id }
    session = BuybackSession.order(:id).last

    post buybacks_session_lines_path(session), params: { title: "Workflow Book" }
    line = session.buyback_lines.last
    line.update!(
      product: @variant.product,
      catalog_item: @variant.product.catalog_item,
      list_price_cents: @variant.product.list_price_cents,
      status: "resolved"
    )

    patch update_proposal_buybacks_session_line_path(session, line), params: {
      product_condition_id: @condition.id,
      sub_department_id: @sub.id,
      proposed_resale_price_cents: 2000,
      proposed_cash_offer_cents: 500,
      proposed_trade_credit_offer_cents: 600,
      resale_override_reason: "Staff proposal",
      cash_override_reason: "Staff proposal",
      trade_credit_override_reason: "Staff proposal"
    }
    assert_response :redirect

    patch save_proposal_buybacks_session_path(session)
    session.reload
    assert session.quoted?
    assert session.buyback_number.present?

    patch open_decision_buybacks_session_path(session)
    assert session.reload.decision?

    patch record_decision_buybacks_session_line_path(session, line.reload), params: { outcome: "accepted_by_customer" }

    patch buybacks_session_path(session), params: { buyback_session: { payout_mode: "cash" } }

    register = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 10_000)
    Current.store = @store
    Current.workstation = @workstation

    patch complete_buybacks_session_path(session)
    session.reload
    assert session.completed?
    assert session.inventory_posting.present?
    assert session.pos_cash_movement.present?
  end
end
