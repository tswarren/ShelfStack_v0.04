# frozen_string_literal: true

require "test_helper"

class Pos::ActiveDraftResolverTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "resolver_cashier")
    @other_cashier = create_user!(username: "resolver_other")
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier)
  end

  test "returns none when no drafts exist" do
    result = Pos::ActiveDraftResolver.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session
    )

    assert_equal :none, result.status
    assert_nil result.draft
    assert_empty result.candidates
    refute result.legacy
  end

  test "returns session-scoped draft when one exists" do
    draft = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )

    result = Pos::ActiveDraftResolver.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session
    )

    assert_equal :found, result.status
    assert_equal draft.id, result.draft.id
    refute result.legacy
  end

  test "returns conflict when multiple session-scoped drafts exist" do
    first = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )
    second = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )

    result = Pos::ActiveDraftResolver.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session
    )

    assert_equal :conflict, result.status
    assert_nil result.draft
    assert_equal [ first.id, second.id ].sort, result.candidates.map(&:id).sort
    refute result.legacy
  end

  test "legacy nil-session draft returns legacy_found when no session-scoped draft exists" do
    legacy = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier
    )

    result = Pos::ActiveDraftResolver.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session
    )

    assert_equal :legacy_found, result.status
    assert_equal legacy.id, result.draft.id
    assert_equal [ legacy.id ], result.candidates.map(&:id)
    assert result.legacy
  end

  test "session-scoped draft wins over legacy nil-session draft" do
    legacy = create_pos_transaction!(store: @store, workstation: @workstation, user: @cashier)
    session_draft = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )

    result = Pos::ActiveDraftResolver.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session
    )

    assert_equal :found, result.status
    assert_equal session_draft.id, result.draft.id
    refute result.legacy
    assert legacy.reload.draft?
  end


  test "stale session-scoped draft is ignored for current register session" do
    stale_session = @register_session
    stale_draft = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: stale_session,
        business_date: stale_session.business_date
      }
    )

    Pos::RegisterSessionLifecycle.close!(
      session: stale_session,
      closed_by_user: @cashier,
      expected_closing_cash_cents: 0,
      counted_closing_cash_cents: 0
    )

    current_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier)

    result = Pos::ActiveDraftResolver.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: current_session
    )

    assert_equal :none, result.status
    assert stale_draft.reload.draft?
  end

  test "scopes drafts to cashier and workstation" do
    other_workstation = create_workstation!(store: @store, attrs: { workstation_number: "002", workstation_code: "001-REG002", name: "Second Register" })
    create_pos_transaction!(store: @store, workstation: other_workstation, user: @cashier)
    create_pos_transaction!(store: @store, workstation: @workstation, user: @other_cashier)

    result = Pos::ActiveDraftResolver.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session
    )

    assert_equal :none, result.status
  end
end
