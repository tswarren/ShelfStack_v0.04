# frozen_string_literal: true

class InventoryLedgerEntry < ApplicationRecord
  MOVEMENT_TYPES = %w[
    opening_balance manual_adjustment correction recount_adjustment
    received sold customer_return used_buyback vendor_return transfer_in transfer_out
  ].freeze

  PHASE4_MOVEMENT_TYPES = %w[opening_balance manual_adjustment correction recount_adjustment].freeze
  COST_SOURCES = %w[manual margin_estimate unknown receipt_cost moving_average buyback_offer no_value_donation].freeze
  RETAIL_SOURCES = %w[variant_selling_price unknown].freeze

  belongs_to :inventory_posting
  belongs_to :product_variant
  belongs_to :store
  belongs_to :inventory_location, optional: true
  belongs_to :inventory_reason_code, optional: true

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :inventory_posting_id }
  validates :movement_type, presence: true, inclusion: { in: MOVEMENT_TYPES }
  validates :quantity_delta, presence: true, numericality: { only_integer: true }
  validates :cost_source, presence: true, inclusion: { in: COST_SOURCES }
  validates :retail_source, presence: true, inclusion: { in: RETAIL_SOURCES }
  validates :occurred_at, presence: true
  validates :unit_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :unit_retail_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_retail_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
