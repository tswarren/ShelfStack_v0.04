# frozen_string_literal: true

class TaxCategory < ApplicationRecord
  has_many :store_tax_category_rates, dependent: :restrict_with_error
  has_many :categories, foreign_key: :default_tax_category_id, dependent: :restrict_with_error,
           inverse_of: :default_tax_category

  validates :name, presence: true, uniqueness: true
  validates :short_name, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :sort_order, numericality: { only_integer: true }

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
  end
end
