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
    get root_path
    assert_redirected_to session_unlock_path
    assert @session.reload.locked?

    post session_unlock_path, params: { password: "Password123!" }
    assert_redirected_to root_path

    follow_redirect!
    assert_not_equal session_unlock_path, path
    assert @session.reload.active?
  end
end
