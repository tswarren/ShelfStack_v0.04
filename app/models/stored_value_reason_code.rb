# frozen_string_literal: true

class StoredValueReasonCode < ApplicationRecord
  has_many :stored_value_ledger_entries, foreign_key: :reason_code_id, dependent: :restrict_with_error,
           inverse_of: :reason_code
  has_many :stored_value_transfers, foreign_key: :reason_code_id, dependent: :restrict_with_error,
           inverse_of: :reason_code

  validates :reason_key, presence: true, uniqueness: true, length: { maximum: 40 }
  validates :name, presence: true, uniqueness: true

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
