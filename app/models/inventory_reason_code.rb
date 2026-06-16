# frozen_string_literal: true

class InventoryReasonCode < ApplicationRecord
  REASON_KEYS = %w[
    opening_balance cycle_count damage shrink data_correction recount
  ].freeze

  has_many :inventory_adjustment_lines, dependent: :restrict_with_error
  has_many :inventory_ledger_entries, dependent: :restrict_with_error

  validates :reason_key, presence: true, uniqueness: true, length: { maximum: 40 }
  validates :name, presence: true, uniqueness: true
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_strings
    self.reason_key = reason_key&.strip&.downcase
    self.name = name&.strip
  end
end
