# frozen_string_literal: true

require "test_helper"

class UserPasswordResetTest < ActiveSupport::TestCase
  setup do
    @user = create_user!(username: "resetme", password: "OldPassword123!")
    @system_user = User.find_or_create_by!(username: ShelfStack::SYSTEM_USERNAME) do |user|
      user.assign_attributes(
        user_type: "system",
        first_name: "ShelfStack",
        last_name: "System",
        display_name: "ShelfStack System",
        interactive_login_enabled: false,
        active: true,
        password: SecureRandom.hex(32)
      )
    end
  end

  test "resets password with provided value" do
    result = UserPasswordReset.call(
      username: "resetme",
      password: "NewPassword123!",
      actor: @system_user
    )

    assert_nil result.generated_password
    assert result.user.authenticate("NewPassword123!")
    assert result.user.force_password_change?
    assert_not_nil result.user.password_changed_at
    assert_nil result.user.locked_at
    assert_equal 0, result.user.invalid_login_attempts
    assert AuditEvent.exists?(event_name: "user.password_reset", auditable: @user)
  end

  test "generates password when not provided" do
    result = UserPasswordReset.call(username: "resetme", actor: @system_user)

    assert result.generated_password.present?
    assert result.user.authenticate(result.generated_password)
  end

  test "clears account lockout by default" do
    @user.update!(locked_at: Time.current, invalid_login_attempts: 5)

    UserPasswordReset.call(username: "resetme", password: "NewPassword123!", actor: @system_user)

    @user.reload
    assert_nil @user.locked_at
    assert_equal 0, @user.invalid_login_attempts
  end

  test "can skip force password change" do
    UserPasswordReset.call(
      username: "resetme",
      password: "NewPassword123!",
      force_password_change: false,
      actor: @system_user
    )

    assert_not @user.reload.force_password_change?
  end

  test "rejects unknown username" do
    error = assert_raises(UserPasswordReset::Error) do
      UserPasswordReset.call(username: "nobody", password: "NewPassword123!", actor: @system_user)
    end

    assert_includes error.message, "User not found"
  end

  test "rejects system user" do
    error = assert_raises(UserPasswordReset::Error) do
      UserPasswordReset.call(user: @system_user, password: "NewPassword123!", actor: @system_user)
    end

    assert_includes error.message, "system user"
  end

  test "rejects mismatched confirmation" do
    error = assert_raises(UserPasswordReset::Error) do
      UserPasswordReset.call(
        username: "resetme",
        password: "NewPassword123!",
        password_confirmation: "Different123!",
        actor: @system_user
      )
    end

    assert_includes error.message, "confirmation"
  end
end
