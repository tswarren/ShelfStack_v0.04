# frozen_string_literal: true

require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "bookseller", password: "Password123!", pin: "5678")
    assign_workstation!(@workstation, cookies)
    login_user!(@user, workstation: @workstation)
  end

  test "rejects password change when confirmation is blank" do
    patch password_path, params: {
      current_password: "Password123!",
      password: "NewPassword123!",
      password_confirmation: ""
    }

    assert_response :unprocessable_entity
    assert_select ".ss-alert--error", text: /confirmation.*blank/i
    assert @user.reload.authenticate("Password123!")
  end

  test "rejects password change when confirmation does not match" do
    patch password_path, params: {
      current_password: "Password123!",
      password: "NewPassword123!",
      password_confirmation: "Different123!"
    }

    assert_response :unprocessable_entity
    assert_match(/confirmation/i, response.body)
    assert @user.reload.authenticate("Password123!")
  end

  test "updates password and clears force_password_change" do
    @user.update!(force_password_change: true)

    patch password_path, params: {
      current_password: "Password123!",
      password: "NewPassword123!",
      password_confirmation: "NewPassword123!"
    }

    assert_redirected_to root_path
    @user.reload
    assert @user.authenticate("NewPassword123!")
    assert_not @user.force_password_change?
    assert AuditEvent.exists?(event_name: "user.password_changed", auditable: @user)
  end

  test "redirects to pin setup after password change when pin is missing" do
    @user.clear_pin!
    @user.update!(force_password_change: true)

    patch password_path, params: {
      current_password: "Password123!",
      password: "NewPassword123!",
      password_confirmation: "NewPassword123!"
    }

    assert_redirected_to edit_pin_path
    assert_match(/set a PIN/i, flash[:notice])
  end
end
