# frozen_string_literal: true

require "test_helper"

class PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "bookseller", password: "Password123!", pin: nil)
    assign_workstation!(@workstation, cookies)
    login_user!(@user, workstation: @workstation)
  end

  test "rejects pin change when confirmation is blank" do
    patch pin_path, params: { pin: "5678", pin_confirmation: "" }

    assert_response :unprocessable_entity
    assert_select ".flash-alert", text: /confirmation.*blank/i
    assert_not @user.reload.pin_set?
  end

  test "rejects pin change when confirmation does not match" do
    patch pin_path, params: { pin: "5678", pin_confirmation: "9999" }

    assert_response :unprocessable_entity
    assert_match(/does not match/i, response.body)
    assert_not @user.reload.pin_set?
  end

  test "sets pin when confirmation matches" do
    patch pin_path, params: { pin: "5678", pin_confirmation: "5678" }

    assert_redirected_to root_path
    assert @user.reload.authenticate_pin("5678")
    assert AuditEvent.exists?(event_name: "user.pin_changed", auditable: @user)
  end
end
