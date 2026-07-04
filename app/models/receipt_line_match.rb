# frozen_string_literal: true

class ReceiptLineMatch < ApplicationRecord
  MATCH_STATUSES = %w[proposed confirmed posted released rejected].freeze
  MATCH_SOURCES = %w[auto manual override file_import edi_x12 api].freeze
  CONFIRMED_STATUSES = %w[confirmed posted].freeze

  belongs_to :store
  belongs_to :receipt
  belongs_to :receipt_line
  belongs_to :purchase_order
  belongs_to :purchase_order_line
  belongs_to :product
  belongs_to :product_variant
  belongs_to :matched_by_user, class_name: "User", optional: true
  belongs_to :released_by_user, class_name: "User", optional: true

  validates :quantity_matched, numericality: { only_integer: true, greater_than: 0 }
  validates :match_status, inclusion: { in: MATCH_STATUSES }
  validates :match_source, inclusion: { in: MATCH_SOURCES }
  validate :consistency_across_records
  validate :purchase_order_matches_receipt_context

  scope :confirmed_matches, -> { where(match_status: CONFIRMED_STATUSES) }

  def confirmed?
    CONFIRMED_STATUSES.include?(match_status)
  end

  private

  def consistency_across_records
    if receipt_line.present? && product_variant_id != receipt_line.product_variant_id
      errors.add(:product_variant, "must match receipt line variant")
    end

    if purchase_order_line.present? && product_variant_id != purchase_order_line.product_variant_id
      errors.add(:product_variant, "must match purchase order line variant")
    end
  end

  def purchase_order_matches_receipt_context
    return if receipt.blank? || purchase_order_line.blank?

    Receiving::ReceiptPoLineMatchConstraints.add_incompatibility_errors(
      receipt: receipt,
      po_line: purchase_order_line,
      errors: errors
    )
  end
end
