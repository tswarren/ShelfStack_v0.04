# frozen_string_literal: true

class PosTransaction < ApplicationRecord
  STATUSES = %w[draft suspended completed voided cancelled].freeze
  TRANSACTION_TYPES = %w[sale return exchange].freeze

  belongs_to :store
  belongs_to :workstation
  belongs_to :user_session, optional: true
  belongs_to :pos_register_session, optional: true
  belongs_to :cashier_user, class_name: "User"

  has_many :pos_transaction_lines, -> { order(:line_number) }, dependent: :destroy, inverse_of: :pos_transaction
  has_many :pos_tenders, dependent: :destroy
  has_one :pos_receipt, dependent: :destroy
  has_one :pos_void, dependent: :restrict_with_error
  has_one :inventory_posting, as: :source, class_name: "InventoryPosting", dependent: :restrict_with_error
  has_many :pos_authorizations, dependent: :nullify

  accepts_nested_attributes_for :pos_transaction_lines, allow_destroy: true
  accepts_nested_attributes_for :pos_tenders, allow_destroy: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }, allow_nil: true
  validates :transaction_number, uniqueness: true, allow_nil: true
  validate :immutable_when_completed, on: :update
  validate :immutable_when_voided, on: :update

  scope :drafts, -> { where(status: "draft") }
  scope :suspended, -> { where(status: "suspended") }
  scope :completed_records, -> { where(status: "completed") }

  def draft?
    status == "draft"
  end

  def suspended?
    status == "suspended"
  end

  def completed?
    status == "completed"
  end

  def voided?
    status == "voided"
  end

  def editable?
    draft? || suspended?
  end

  private

  def immutable_when_completed
    return unless status_in_database == "completed"

    allowed_changes = changed_attributes.keys - ["updated_at"]
    if allowed_changes.sort == %w[status voided_at] && status == "voided"
      return
    end

    errors.add(:base, "completed transactions are immutable")
  end

  def immutable_when_voided
    return unless status_in_database == "voided"

    errors.add(:base, "voided transactions are immutable")
  end
end
