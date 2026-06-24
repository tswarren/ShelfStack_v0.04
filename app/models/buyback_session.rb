# frozen_string_literal: true

class BuybackSession < ApplicationRecord
  STATUSES = %w[draft quoted decision completed cancelled voided].freeze
  PAYOUT_MODES = %w[cash trade_credit no_value_donation].freeze

  belongs_to :store
  belongs_to :workstation, optional: true
  belongs_to :pos_register_session, optional: true
  belongs_to :customer
  belongs_to :stored_value_account, optional: true
  belongs_to :stored_value_ledger_entry, optional: true, class_name: "StoredValueLedgerEntry"
  belongs_to :pos_cash_movement, optional: true
  belongs_to :inventory_posting, optional: true, class_name: "InventoryPosting"
  belongs_to :created_by_user, class_name: "User"
  belongs_to :completed_by_user, class_name: "User", optional: true
  belongs_to :cancelled_by_user, class_name: "User", optional: true
  belongs_to :voided_by_user, class_name: "User", optional: true

  has_many :buyback_lines, dependent: :destroy
  has_one :buyback_void, dependent: :restrict_with_error
  has_one :inventory_posting_as_source, as: :source, class_name: "InventoryPosting", dependent: :restrict_with_error

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payout_mode, inclusion: { in: PAYOUT_MODES }, allow_blank: true
  validates :buyback_number, uniqueness: { scope: :store_id }, allow_nil: true
  validates :customer_id, presence: true

  scope :for_store, ->(store) { where(store: store) }

  def draft?
    status == "draft"
  end

  def quoted?
    status == "quoted"
  end

  def decision?
    status == "decision"
  end

  def completed?
    status == "completed"
  end

  def cancelled?
    status == "cancelled"
  end

  def voided?
    status == "voided"
  end

  def editable?
    draft? || quoted? || decision?
  end
end
