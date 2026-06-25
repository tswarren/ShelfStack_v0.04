# frozen_string_literal: true

require "test_helper"

class SessionLocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "nopinuser", password: "Password123!", pin: nil)
    assign_workstation!(@workstation, cookies)
    login_user!(@user, workstation: @workstation)
    @session = UserSession.active_records.find_by!(user: @user)
    @session.update!(last_activity_at: (ShelfStack::SESSION_INACTIVITY_TIMEOUT + 1.minute).ago)
  end

  test "password unlock after inactivity lock stays active on next request" do
    get items_root_path

    assert_redirected_to session_unlock_path
    assert @session.reload.locked?
    assert_equal items_root_path, @session.locked_return_path

    post session_unlock_path, params: { password: "Password123!" }
    assert_redirected_to items_root_path

    follow_redirect!
    assert_not_equal session_unlock_path, path
    assert @session.reload.active?
    assert_nil @session.locked_return_path
  end

  test "manual lock returns to captured page after unlock" do
    post session_lock_path, params: { return_to: items_root_path }
    assert_redirected_to session_unlock_path
    assert_equal items_root_path, @session.reload.locked_return_path

    post session_unlock_path, params: { password: "Password123!" }
    assert_redirected_to items_root_path
  end

  test "unlock falls back to root when return path is invalid" do
    @session.lock!(return_path: "https://evil.example/phish")

    get root_path
    assert_redirected_to session_unlock_path

    post session_unlock_path, params: { password: "Password123!" }
    assert_redirected_to root_path
  end
end
