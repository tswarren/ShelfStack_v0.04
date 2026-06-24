# frozen_string_literal: true

require "test_helper"

class Buybacks::AuthorizationReviewFixesTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @viewer = create_user!(username: "buyback_viewer")
    grant_permission!(@viewer, "buybacks.view", store: @store)
    @session = create_buyback_session!(
      store: @store,
      customer: create_buyback_customer!,
      actor: create_user!(username: "buyback_admin"),
      workstation: @workstation
    )
    @line = Buybacks::AddLine.call!(session: @session, actor: create_user!, title_snapshot: "Auth Test")
    login_user!(@viewer, workstation: @workstation)
  end

  test "unauthorized user cannot update proposal via controller" do
    patch update_proposal_buybacks_session_line_path(@session, @line), params: {
      proposed_resale_price_cents: 1000
    }

    assert_response :redirect
    assert_match(/not authorized/i, flash[:alert].to_s)
    assert_nil @line.reload.proposed_resale_price_cents
  end
end
