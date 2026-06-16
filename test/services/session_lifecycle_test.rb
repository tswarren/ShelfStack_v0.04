# frozen_string_literal: true

require "test_helper"

class SessionLifecycleTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: nil)
    @user.pin = "5678"
    @user.save!
    @assignment = WorkstationAssignment.create!(
      workstation: @workstation,
      assignment_token_digest: TokenDigest.digest("test-token"),
      assigned_at: Time.current
    )
    @session = UserSession.create!(
      user: @user,
      store: @store,
      workstation: @workstation,
      session_token_digest: TokenDigest.digest("session-token"),
      status: "active",
      last_activity_at: Time.current
    )
    Current.user = @user
    Current.user_session = @session
    Current.store = @store
    Current.workstation = @workstation
  end

  teardown { Current.reset }

  test "lock and unlock with pin" do
    SessionLifecycle.lock!(session: @session, actor: @user)
    assert @session.reload.locked?

    SessionLifecycle.unlock!(session: @session, user: @user, pin: "5678")
    assert @session.reload.active?
  end

  test "unlock with password when user has no pin" do
    @user.clear_pin!
    SessionLifecycle.lock!(session: @session, actor: @user)

    SessionLifecycle.unlock!(session: @session, user: @user, password: "Password123!")
    assert @session.reload.active?
  end

  test "inactivity locks session instead of expiring it" do
    @session.update!(last_activity_at: (ShelfStack::SESSION_INACTIVITY_TIMEOUT + 1.minute).ago)

    SessionLifecycle.check_inactivity!(@session)

    assert @session.reload.locked?
    assert_not_equal "expired", @session.status
  end

  test "terminal session cannot return to active" do
    @session.end!
    assert @session.terminal?
    assert_not @session.update(status: "active")
    assert_includes @session.errors[:status], "cannot return to active from a terminal status"
  end
end
