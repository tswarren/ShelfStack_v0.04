# frozen_string_literal: true

class BuybackPricingRule < ApplicationRecord
  BASE_PRICE_SOURCES = %w[
    product_list_price
    variant_selling_price
    condition_adjusted_list_price
    manual_resale_price
  ].freeze

  belongs_to :sub_department, optional: true
  belongs_to :product_condition, optional: true

  validates :name, presence: true
  validates :base_price_source, presence: true, inclusion: { in: BASE_PRICE_SOURCES }
  validates :cash_offer_bps, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 }
  validates :trade_credit_offer_bps, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 }
  validates :minimum_offer_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rounding_increment_cents, numericality: { only_integer: true, greater_than: 0 }

  scope :active_records, -> { where(active: true) }
end
