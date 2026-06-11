# frozen_string_literal: true

class ProductCondition < ApplicationRecord
  has_many :product_variants, foreign_key: :condition_id, dependent: :restrict_with_error,
           inverse_of: :condition

  validates :condition_key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :short_name, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :sku_component, uniqueness: true, length: { maximum: 5 }, allow_blank: true
  validates :sort_order, numericality: { only_integer: true }
  validates :default_list_price_factor_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 }

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
    self.condition_key = condition_key&.strip&.downcase
    self.name = name&.strip
    self.short_name = short_name&.strip
    self.sku_component = sku_component&.strip&.upcase.presence
  end
end
