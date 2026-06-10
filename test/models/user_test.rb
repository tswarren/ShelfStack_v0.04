# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes username to lowercase" do
    user = create_user!(username: "TestUser")
    assert_equal "testuser", user.username
  end

  test "system user cannot be interactive" do
    user = User.new(
      user_type: "system",
      username: "system",
      first_name: "Sys",
      last_name: "Tem",
      display_name: "System",
      password: "x",
      interactive_login_enabled: true,
      active: true
    )
    assert_not user.valid?
  end

  test "records failed login and locks out" do
    user = create_user!
    ShelfStack::LOGIN_LOCKOUT_THRESHOLD.times { user.record_failed_login! }
    assert user.locked_out?
  end

  test "authenticate pin" do
    user = create_user!
    user.pin = "1234"
    user.save!
    assert user.authenticate_pin("1234")
    assert_not user.authenticate_pin("9999")
  end
end
