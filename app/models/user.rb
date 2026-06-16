# frozen_string_literal: true

class User < ApplicationRecord
  USER_TYPES = %w[user admin system].freeze

  has_secure_password validations: false

  belongs_to :default_store, class_name: "Store", optional: true
  has_many :user_role_assignments, dependent: :restrict_with_error
  has_many :roles, through: :user_role_assignments
  has_many :user_sessions, dependent: :restrict_with_error
  has_many :assigned_role_assignments,
           class_name: "UserRoleAssignment",
           foreign_key: :assigned_by_user_id,
           dependent: :nullify,
           inverse_of: :assigned_by_user
  has_many :assigned_workstation_assignments,
           class_name: "WorkstationAssignment",
           foreign_key: :assigned_by_user_id,
           dependent: :nullify,
           inverse_of: :assigned_by_user
  has_many :ended_sessions,
           class_name: "UserSession",
           foreign_key: :ended_by_user_id,
           dependent: :nullify,
           inverse_of: :ended_by_user
  has_many :audit_events_as_actor,
           class_name: "AuditEvent",
           foreign_key: :actor_user_id,
           dependent: :restrict_with_error,
           inverse_of: :actor_user

  validates :username, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 50 }
  validates :first_name, :last_name, :display_name, presence: true
  validates :user_type, inclusion: { in: USER_TYPES }
  validates :clerk_number, uniqueness: true, allow_nil: true, length: { maximum: 10 }
  validates :password, confirmation: true, if: -> { password.present? }
  validate :password_required_for_interactive_users
  validate :system_user_rules

  def pin_set?
    pin_digest.present?
  end

  before_validation :normalize_username

  scope :active_records, -> { where(active: true) }
  scope :interactive, -> { where(interactive_login_enabled: true).where.not(user_type: "system") }

  def system_user?
    user_type == "system" || username == ShelfStack::SYSTEM_USERNAME
  end

  def interactive?
    interactive_login_enabled? && !system_user? && active?
  end

  def locked_out?
    locked_at.present?
  end

  def authenticate_pin(pin)
    return false if pin_digest.blank? || pin.blank?

    BCrypt::Password.new(pin_digest) == pin.to_s
  end

  def pin=(value)
    if value.blank?
      self.pin_digest = nil
      self.pin_changed_at = nil
    else
      self.pin_digest = BCrypt::Password.create(value)
      self.pin_changed_at = Time.current
    end
  end

  def clear_pin!
    update!(pin_digest: nil, pin_changed_at: nil)
  end

  def record_failed_login!
    increment!(:invalid_login_attempts)
    if invalid_login_attempts >= ShelfStack::LOGIN_LOCKOUT_THRESHOLD
      update!(locked_at: Time.current)
    end
  end

  def record_successful_login!
    update!(
      previous_login_at: last_login_at,
      last_login_at: Time.current,
      invalid_login_attempts: 0,
      locked_at: nil
    )
  end

  def inactivate!
    update!(active: false, deactivated_at: Time.current)
  end

  def reactivate!
    update!(active: true, deactivated_at: nil)
  end

  private

  def normalize_username
    self.username = username&.downcase&.strip
  end

  def password_required_for_interactive_users
    return if system_user?
    return if password_digest.present?

    errors.add(:password, "can't be blank") if interactive_login_enabled?
  end

  def system_user_rules
    return unless system_user?

    errors.add(:interactive_login_enabled, "must be false for system user") if interactive_login_enabled?
    errors.add(:user_type, "must be system for system user") unless user_type == "system"
  end
end
