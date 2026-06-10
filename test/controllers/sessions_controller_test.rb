# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "bookseller", password: "Password123!")
    grant_permission!(@user, "setup.access")
  end

  test "login with valid credentials and workstation assignment" do
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "bookseller", password: "Password123!" }
    assert_redirected_to root_path
    assert UserSession.active_records.exists?(user: @user)
    assert AuditEvent.exists?(event_name: "user.login")
  end

  test "login fails without workstation assignment" do
    post login_path, params: { username: "bookseller", password: "Password123!" }
    assert_response :unprocessable_entity
    assert_not UserSession.exists?(user: @user)
  end

  test "logout ends session" do
    grant_permission!(@user, "workstations.assign_browser")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "bookseller", password: "Password123!" }
    follow_redirect! if response.redirect?
    delete logout_path
    assert_redirected_to login_path
  end

  test "header user menu links to password and pin pages" do
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "bookseller", password: "Password123!" }
    follow_redirect!

    assert_select ".ss-dropdown-menu a[href='#{edit_password_path}']", text: "Change password"
    assert_select ".ss-dropdown-menu a[href='#{edit_pin_path}']", text: "Set PIN"
  end
end
