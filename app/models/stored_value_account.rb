# frozen_string_literal: true

class StoredValueAccount < ApplicationRecord
  ACCOUNT_TYPES = %w[
    merchandise_credit
    trade_credit
    gift_card
    promo_credit
    legacy_credit
    manual_store_credit
  ].freeze

  belongs_to :issuing_store, class_name: "Store"
  belongs_to :customer, optional: true

  has_many :stored_value_identifiers, dependent: :restrict_with_error
  has_many :stored_value_ledger_entries, dependent: :restrict_with_error
  has_many :outgoing_transfers, class_name: "StoredValueTransfer", foreign_key: :from_account_id,
           dependent: :restrict_with_error, inverse_of: :from_account
  has_many :incoming_transfers, class_name: "StoredValueTransfer", foreign_key: :to_account_id,
           dependent: :restrict_with_error, inverse_of: :to_account

  validates :account_type, presence: true, inclusion: { in: ACCOUNT_TYPES }
  validates :current_balance_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :issuing_store, presence: true

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def suspend!
    update!(active: false)
  end

  def close!
    if current_balance_cents.positive?
      errors.add(:base, "Account must have zero balance before closing")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(active: false)
  end

  def postable?
    active?
  end

  private

  def normalize_strings
    self.holder_name_snapshot = holder_name_snapshot&.strip.presence
    self.notes = notes&.strip.presence
  end
end
