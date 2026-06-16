# frozen_string_literal: true

class InventoryLocation < ApplicationRecord
  belongs_to :store

  has_many :inventory_adjustment_lines, dependent: :restrict_with_error
  has_many :inventory_ledger_entries, dependent: :restrict_with_error

  validates :name, presence: true
  validates :short_name, presence: true, length: { maximum: 40 }
  validates :short_name, uniqueness: { scope: :store_id, case_sensitive: false }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings
  validate :store_must_be_active

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_strings
    self.name = name&.strip
    self.short_name = short_name&.strip
  end

  def store_must_be_active
    return if store.blank? || store.active?

    errors.add(:store, "must be active")
  end
end
