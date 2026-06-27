# frozen_string_literal: true

require "test_helper"

class Pos::LandingRouterTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "landing_router_cashier")
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier)
  end

  test "returns closed when register session is missing" do
    result = Pos::LandingRouter.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: nil
    )

    assert_equal :closed, result.status
  end

  test "returns idle when no active draft exists" do
    result = Pos::LandingRouter.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session
    )

    assert_equal :idle, result.status
  end

  test "returns active_draft when session-scoped draft exists" do
    draft = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )

    result = Pos::LandingRouter.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session
    )

    assert_equal :active_draft, result.status
    assert_equal draft.id, result.draft.id
  end

  test "returns legacy_found for nil-session draft" do
    legacy = create_pos_transaction!(store: @store, workstation: @workstation, user: @cashier)

    result = Pos::LandingRouter.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session
    )

    assert_equal :legacy_found, result.status
    assert_equal [ legacy.id ], result.candidates.map(&:id)
  end
end
