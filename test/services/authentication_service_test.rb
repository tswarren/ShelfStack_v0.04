# frozen_string_literal: true

require "test_helper"

class AuthenticationServiceTest < ActiveSupport::TestCase
  test "successful authentication" do
    user = create_user!(username: "alice", password: "Password123!")
    result = AuthenticationService.authenticate(username: "alice", password: "Password123!")
    assert result[:success]
    assert_equal user, result[:user]
  end

  test "failed authentication does not reveal user existence" do
    result = AuthenticationService.authenticate(username: "nobody", password: "wrong")
    assert_not result[:success]
    assert_equal AuthenticationService::GENERIC_LOGIN_ERROR, result[:message]
  end

  test "system user cannot authenticate interactively" do
    User.create!(
      user_type: "system",
      username: "system",
      first_name: "S",
      last_name: "S",
      display_name: "System",
      password: "Password123!",
      interactive_login_enabled: false,
      active: true
    )
    result = AuthenticationService.authenticate(username: "system", password: "Password123!")
    assert_not result[:success]
  end
end
