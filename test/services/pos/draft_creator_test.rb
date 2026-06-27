# frozen_string_literal: true

require "test_helper"

class Pos::DraftCreatorTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "draft_creator_cashier")
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier)
    @user_session = UserSession.create!(
      user: @cashier,
      workstation: @workstation,
      store: @store,
      session_token_digest: TokenDigest.digest("draft-creator-session"),
      status: "active",
      last_activity_at: Time.current
    )
  end

  test "creates stamped draft when none exists" do
    result = Pos::DraftCreator.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session,
      user_session: @user_session
    )

    assert_equal :created, result.status
    transaction = result.transaction
    assert_equal @register_session.id, transaction.pos_register_session_id
    assert_equal @register_session.business_date, transaction.business_date
    assert_equal @workstation.id, transaction.workstation_id
    assert_equal @cashier.id, transaction.cashier_user_id
    assert_equal @user_session.id, transaction.user_session_id
    assert transaction.draft?
  end

  test "resumes existing session-scoped draft instead of creating second" do
    existing = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )

    result = Pos::DraftCreator.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session,
      user_session: @user_session
    )

    assert_equal :resumed, result.status
    assert_equal existing.id, result.transaction.id
    assert_equal 1, PosTransaction.drafts.where(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      pos_register_session: @register_session
    ).count
  end

  test "resumes legacy nil-session draft when no session-scoped draft exists" do
    legacy = create_pos_transaction!(store: @store, workstation: @workstation, user: @cashier)

    result = Pos::DraftCreator.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session,
      user_session: @user_session
    )

    assert_equal :resumed, result.status
    assert_equal legacy.id, result.transaction.id
  end

  test "returns conflict when multiple session-scoped drafts exist" do
    create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )
    create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )

    result = Pos::DraftCreator.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session,
      user_session: @user_session
    )

    assert_equal :conflict, result.status
    assert_nil result.transaction
    assert_equal 2, result.candidates.size
  end

  test "returns missing register session when register is closed" do
    Pos::RegisterSessionLifecycle.close!(
      session: @register_session,
      closed_by_user: @cashier,
      expected_closing_cash_cents: 0,
      counted_closing_cash_cents: 0
    )

    result = Pos::DraftCreator.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session,
      user_session: @user_session
    )

    assert_equal :missing_register_session, result.status
  end

  test "call! raises on conflict" do
    create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )
    create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )

    assert_raises(Pos::DraftCreator::Error) do
      Pos::DraftCreator.call!(
        store: @store,
        workstation: @workstation,
        cashier_user: @cashier,
        register_session: @register_session,
        user_session: @user_session
      )
    end
  end
end
