# frozen_string_literal: true

class PosTransactionLine < ApplicationRecord
  LINE_TYPES = %w[variant open_ring gift_card_sale].freeze
  RETURN_DISPOSITIONS = %w[
    return_to_stock damaged defective return_to_vendor_candidate other
  ].freeze
  COGS_SOURCES = Pos::LineCogsCalculator::COGS_SOURCES
  REVENUE_TREATMENTS = Pos::LineCogsCalculator::REVENUE_TREATMENTS
  INVENTORY_TRACKING_SNAPSHOTS = Inventory::TrackingResolver::TRACKING_VALUES
  COSTING_METHOD_SNAPSHOTS = %w[
    moving_average unit_cost receipt_cost buyback_offer margin_estimate
    return_reversal none unknown
  ].freeze
  GIFT_CARD_SALE_DESCRIPTION = "Gift card"
  APPLIED_TAX_SOURCES = Pos::TaxRecalculator::APPLIED_TAX_SOURCES

  belongs_to :pos_transaction
  belongs_to :product_variant, optional: true
  belongs_to :product, optional: true
  belongs_to :sub_department, optional: true
  belongs_to :tax_category, optional: true
  belongs_to :store_tax_rate, optional: true
  belongs_to :normal_tax_category, class_name: "TaxCategory", optional: true
  belongs_to :normal_store_tax_rate, class_name: "StoreTaxRate", optional: true
  belongs_to :source_transaction, class_name: "PosTransaction", optional: true
  belongs_to :source_transaction_line, class_name: "PosTransactionLine", optional: true
  belongs_to :demand_allocation, optional: true
  belongs_to :stored_value_account, optional: true
  belongs_to :stored_value_identifier, optional: true

  has_many :pos_discount_applications, dependent: :destroy
  has_many :pos_discount_allocations, dependent: :destroy
  has_many :pos_line_tax_overrides, dependent: :destroy

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :pos_transaction_id }
  validates :line_type, presence: true, inclusion: { in: LINE_TYPES }
  validates :quantity, presence: true, numericality: { only_integer: true, other_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :line_discount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :extended_price_cents, numericality: { only_integer: true }
  validates :tax_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :normal_tax_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :applied_tax_source, inclusion: { in: APPLIED_TAX_SOURCES }, allow_nil: true
  validates :return_disposition, inclusion: { in: RETURN_DISPOSITIONS }, allow_nil: true
  validates :cogs_source, inclusion: { in: COGS_SOURCES }, allow_nil: true
  validates :revenue_treatment, inclusion: { in: REVENUE_TREATMENTS }, allow_nil: true
  validates :inventory_tracking_snapshot, inclusion: { in: INVENTORY_TRACKING_SNAPSHOTS }, allow_nil: true
  validates :costing_method_snapshot, inclusion: { in: COSTING_METHOD_SNAPSHOTS }, allow_nil: true
  validates :unit_cogs_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_cogs_cents, numericality: { only_integer: true }, allow_nil: true
  validate :variant_required_for_variant_line
  validate :gift_card_sale_line_constraints
  validate :cannot_edit_when_transaction_locked, on: :update

  def variant_line?
    line_type == "variant"
  end

  def open_ring_line?
    line_type == "open_ring"
  end

  def gift_card_sale_line?
    line_type == "gift_card_sale"
  end

  def return_line?
    quantity.negative?
  end

  def merchandise_line?
    variant_line? || open_ring_line? || gift_card_sale_line?
  end

  def reload_gift_card_sale?
    gift_card_sale_line? && stored_value_account_id.present?
  end

  private

  def variant_required_for_variant_line
    return unless variant_line?
    return if product_variant_id.present?

    errors.add(:product_variant, "must be present for variant lines")
  end

  def gift_card_sale_line_constraints
    return unless gift_card_sale_line?

    if quantity != 1
      errors.add(:quantity, "must be 1 for gift card sales")
    end

    if unit_price_cents.to_i <= 0
      errors.add(:unit_price_cents, "must be positive for gift card sales")
    end

    if product_variant_id.present? || product_id.present?
      errors.add(:base, "gift card sale lines cannot reference catalog products")
    end

    if generate_stored_value_identifier? && stored_value_identifier_id.present?
      errors.add(:generate_stored_value_identifier, "cannot be combined with an assigned identifier")
    end
  end

  def cannot_edit_when_transaction_locked
    return if pos_transaction.blank? || pos_transaction.editable?

    errors.add(:base, "cannot modify lines on a locked transaction")
  end
end
