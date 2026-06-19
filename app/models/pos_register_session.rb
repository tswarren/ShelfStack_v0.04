# frozen_string_literal: true

class PosRegisterSession < ApplicationRecord
  STATUSES = %w[open closed force_closed].freeze

  belongs_to :store
  belongs_to :workstation
  belongs_to :opened_by_user, class_name: "User"
  belongs_to :closed_by_user, class_name: "User", optional: true

  has_many :pos_cash_movements, dependent: :restrict_with_error
  has_many :pos_transactions, dependent: :restrict_with_error
  has_many :pos_voids, dependent: :restrict_with_error
  has_many :pos_authorizations, dependent: :nullify

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :business_date, presence: true
  validates :opening_cash_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :expected_closing_cash_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :counted_closing_cash_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :opened_at, presence: true
  validate :only_one_open_session_per_workstation, if: -> { status == "open" }

  scope :open_sessions, -> { where(status: "open") }

  def open?
    status == "open"
  end

  def self.open_for_workstation(workstation)
    open_sessions.find_by(workstation: workstation)
  end

  private

  def only_one_open_session_per_workstation
    existing = self.class.open_sessions.where(workstation_id: workstation_id)
    existing = existing.where.not(id: id) if persisted?
    return unless existing.exists?

    errors.add(:workstation, "already has an open register session")
  end
end
