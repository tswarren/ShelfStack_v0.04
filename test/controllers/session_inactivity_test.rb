# frozen_string_literal: true

require "test_helper"

class SessionInactivityTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "bookseller", password: "Password123!")
    assign_workstation!(@workstation, cookies)
    login_user!(@user, workstation: @workstation)
    @session = UserSession.active_records.find_by!(user: @user)
    @session.update!(last_activity_at: (ShelfStack::SESSION_INACTIVITY_TIMEOUT + 1.minute).ago)
  end

  test "inactivity redirects to unlock screen not login" do
    get root_path

    assert_redirected_to session_unlock_path
    assert @session.reload.locked?
    assert_not_equal "expired", @session.status
  end
end
