# frozen_string_literal: true

require "test_helper"

class Buybacks::LineMatchContextTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @customer = create_buyback_customer!
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Match Context Book")
  end

  test "valid when session and line belong to store and session is editable" do
    context = Buybacks::LineMatchContext.from_params(
      {
        return_to: Buybacks::LineMatchContext::RETURN_TO,
        buyback_session_id: @session.id,
        line_id: @line.id
      },
      store: @store
    )

    assert context.valid?
    assert_includes context.banner_label, @line.title_snapshot
    assert_includes context.return_path, "buybacks/sessions/#{@session.id}"
  end

  test "invalid when session is completed" do
    @session.update!(status: "completed", completed_at: Time.current)
    context = Buybacks::LineMatchContext.from_params(
      {
        return_to: Buybacks::LineMatchContext::RETURN_TO,
        buyback_session_id: @session.id,
        line_id: @line.id
      },
      store: @store
    )

    assert_not context.valid?
  end
end
