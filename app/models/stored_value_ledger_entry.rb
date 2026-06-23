# frozen_string_literal: true

class StoredValueLedgerEntry < ApplicationRecord
  ENTRY_TYPES = %w[issue redeem adjust transfer_out transfer_in void_reversal].freeze
  MANUAL_ENTRY_TYPES = %w[issue adjust transfer_out transfer_in void_reversal].freeze

  belongs_to :stored_value_account
  belongs_to :store
  belongs_to :reason_code, class_name: "StoredValueReasonCode", optional: true
  belongs_to :created_by_user, class_name: "User"
  belongs_to :reverses_entry, class_name: "StoredValueLedgerEntry", optional: true
  belongs_to :source, polymorphic: true, optional: true

  has_one :void_reversal, class_name: "StoredValueLedgerEntry", foreign_key: :reverses_entry_id,
          inverse_of: :reverses_entry, dependent: :restrict_with_error
  has_one :transfer_out_header, class_name: "StoredValueTransfer", foreign_key: :transfer_out_entry_id,
          inverse_of: :transfer_out_entry, dependent: :restrict_with_error
  has_one :transfer_in_header, class_name: "StoredValueTransfer", foreign_key: :transfer_in_entry_id,
          inverse_of: :transfer_in_entry, dependent: :restrict_with_error

  validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }
  validates :amount_delta_cents, presence: true, numericality: { only_integer: true, other_than: 0 }
  validates :posted_at, presence: true
  validates :reason_code, presence: true, if: :manual_entry_type?

  scope :posted_order, -> { order(posted_at: :desc, id: :desc) }

  def manual_entry_type?
    MANUAL_ENTRY_TYPES.include?(entry_type)
  end
end
