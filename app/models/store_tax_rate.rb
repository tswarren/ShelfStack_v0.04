# frozen_string_literal: true

class StoreTaxRate < ApplicationRecord
  belongs_to :store
  has_many :store_tax_category_rates, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :store_id }
  validates :short_name, presence: true, uniqueness: { scope: :store_id }, length: { maximum: 20 }
  validates :tax_identifier, presence: true, uniqueness: { scope: :store_id }, length: { maximum: 1 }
  validates :tax_rate_bps, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 }

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
    self.name = name&.strip
    self.short_name = short_name&.strip
    self.tax_identifier = tax_identifier&.strip&.upcase
  end
end
