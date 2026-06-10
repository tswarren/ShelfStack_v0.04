# frozen_string_literal: true

class UserSession < ApplicationRecord
  STATUSES = %w[active locked ended expired force_ended].freeze
  TERMINAL_STATUSES = %w[ended expired force_ended].freeze

  belongs_to :user
  belongs_to :store, optional: true
  belongs_to :workstation, optional: true
  belongs_to :ended_by_user, class_name: "User", optional: true
  has_many :audit_events, dependent: :nullify

  validates :session_token_digest, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :last_activity_at, presence: true
  validate :terminal_status_cannot_reactivate, on: :update

  scope :active_records, -> { where(status: "active") }
  scope :locked_records, -> { where(status: "locked") }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def active?
    status == "active"
  end

  def locked?
    status == "locked"
  end

  def touch_activity!
    update!(last_activity_at: Time.current)
  end

  def lock!
    update!(status: "locked", locked_at: Time.current)
  end

  def unlock!
    update!(status: "active", unlocked_at: Time.current, locked_at: nil)
  end

  def end!(ended_by: nil)
    update!(status: "ended", ended_at: Time.current, ended_by_user: ended_by)
  end

  def expire!
    update!(status: "expired", ended_at: Time.current)
  end

  def force_end!(ended_by:)
    update!(status: "force_ended", ended_at: Time.current, ended_by_user: ended_by)
  end

  private

  def terminal_status_cannot_reactivate
    return unless status_changed? && status == "active"
    return unless status_was.in?(TERMINAL_STATUSES)

    errors.add(:status, "cannot return to active from a terminal status")
  end
end
