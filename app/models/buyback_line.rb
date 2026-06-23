# frozen_string_literal: true

class BuybackLine < ApplicationRecord
  STATUSES = %w[pending priced accepted rejected posted voided].freeze
  OUTCOMES = %w[
    accepted_for_cash
    accepted_for_trade_credit
    accepted_as_donation
    rejected_returned_to_seller
    rejected_recycle
  ].freeze

  belongs_to :buyback_session
  belongs_to :catalog_item, optional: true
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  belongs_to :created_catalog_item, class_name: "CatalogItem", optional: true
  belongs_to :created_product, class_name: "Product", optional: true
  belongs_to :created_product_variant, class_name: "ProductVariant", optional: true
  belongs_to :product_condition, optional: true
  belongs_to :buyback_pricing_rule, optional: true
  belongs_to :buyback_reject_reason, optional: true
  belongs_to :sub_department, optional: true
  belongs_to :inventory_ledger_entry, optional: true, class_name: "InventoryLedgerEntry"
  belongs_to :void_inventory_ledger_entry, optional: true, class_name: "InventoryLedgerEntry"

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :buyback_session_id }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :outcome, inclusion: { in: OUTCOMES }, allow_blank: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  def accepted_for_posting?
    outcome.in?(%w[accepted_for_cash accepted_for_trade_credit accepted_as_donation])
  end

  def donation?
    outcome == "accepted_as_donation"
  end

  def rejected?
    outcome.in?(%w[rejected_returned_to_seller rejected_recycle])
  end
end
