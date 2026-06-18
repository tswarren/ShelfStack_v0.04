# frozen_string_literal: true

class InventoryBalance < ApplicationRecord
  COST_SOURCES = InventoryLedgerEntry::COST_SOURCES
  RETAIL_SOURCES = InventoryLedgerEntry::RETAIL_SOURCES

  belongs_to :store
  belongs_to :product_variant
  belongs_to :last_posting, class_name: "InventoryPosting", optional: true

  validates :quantity_on_hand, presence: true, numericality: { only_integer: true }
  validates :quantity_available, presence: true, numericality: { only_integer: true }
  validates :inventory_cost_value_cents, presence: true, numericality: { only_integer: true }
  validates :inventory_retail_value_cents, presence: true, numericality: { only_integer: true }
  validates :store_id, uniqueness: { scope: :product_variant_id }
  validates :unit_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :moving_average_unit_cost_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :unit_retail_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cost_source, inclusion: { in: COST_SOURCES }, allow_nil: true
  validates :retail_source, inclusion: { in: RETAIL_SOURCES }, allow_nil: true

  scope :negative_on_hand, -> { where("quantity_on_hand < 0") }
  scope :for_store, ->(store) { where(store: store) }

  def negative_on_hand?
    quantity_on_hand.negative?
  end
end
