# frozen_string_literal: true

class AuthenticationService
  class Error < StandardError; end

  GENERIC_LOGIN_ERROR = "Invalid username or password."

  def self.authenticate(username:, password:)
    normalized = username.to_s.downcase.strip
    user = User.find_by(username: normalized)

    if user.nil?
      return { success: false, user: nil, message: GENERIC_LOGIN_ERROR }
    end

    unless user.interactive?
      record_failed_login(user)
      return { success: false, user: user, message: GENERIC_LOGIN_ERROR }
    end

    if user.locked_out?
      return { success: false, user: user, message: GENERIC_LOGIN_ERROR }
    end

    if user.authenticate(password)
      { success: true, user: user, message: nil }
    else
      record_failed_login(user)
      { success: false, user: user, message: GENERIC_LOGIN_ERROR }
    end
  end

  def self.record_failed_login(user)
    return unless user

    user.record_failed_login!
    AuditEvents.record!(
      actor: user,
      event_name: "user.login_failed",
      auditable: user,
      details: { invalid_login_attempts: user.invalid_login_attempts }
    )
  end
end
