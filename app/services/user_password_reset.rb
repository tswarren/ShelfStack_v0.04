# frozen_string_literal: true

class UserPasswordReset
  class Error < StandardError; end

  Result = Struct.new(:user, :generated_password, keyword_init: true)

  GENERATED_PASSWORD_LENGTH = 16

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(user: nil, username: nil, password: nil, password_confirmation: nil,
                 force_password_change: true, unlock_account: true, actor: nil)
    @user = user
    @username = username
    @password = password
    @password_confirmation = password_confirmation
    @force_password_change = force_password_change
    @unlock_account = unlock_account
    @actor = actor
  end

  def call
    user = resolve_user!
    raise Error, "The system user password cannot be reset" if user.system_user?

    generated = @password.blank?
    new_password = generated ? generate_password : @password.to_s
    confirmation = @password_confirmation.presence || new_password

    if new_password != confirmation
      raise Error, "Password confirmation does not match"
    end

    if new_password.blank?
      raise Error, "Password can't be blank"
    end

    user.password = new_password
    user.password_confirmation = confirmation
    user.force_password_change = @force_password_change
    user.password_changed_at = Time.current

    if @unlock_account
      user.locked_at = nil
      user.invalid_login_attempts = 0
    end

    user.save!

    AuditEvents.record!(
      actor: resolve_actor!,
      event_name: "user.password_reset",
      auditable: user,
      details: {
        "username" => user.username,
        "force_password_change" => @force_password_change,
        "unlock_account" => @unlock_account,
        "source" => "cli"
      }
    )

    Result.new(user: user, generated_password: generated ? new_password : nil)
  end

  private

  def resolve_user!
    return @user if @user.present?

    username = @username.to_s.strip.downcase
    raise Error, "Username is required" if username.blank?

    user = User.find_by(username: username)
    raise Error, "User not found: #{username}" if user.blank?

    user
  end

  def resolve_actor!
    @actor || User.find_by!(username: ShelfStack::SYSTEM_USERNAME)
  end

  def generate_password
    # Avoid ambiguous characters; satisfy typical interactive login expectations.
    charset = ("a".."z").to_a + ("A".."Z").to_a + ("2".."9").to_a
    Array.new(GENERATED_PASSWORD_LENGTH) { charset.sample(random: SecureRandom) }.join
  end
end
