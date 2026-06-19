# frozen_string_literal: true

class PosTransactionLine < ApplicationRecord
  LINE_TYPES = %w[variant open_ring].freeze
  RETURN_DISPOSITIONS = %w[
    return_to_stock damaged defective return_to_vendor_candidate other
  ].freeze

  belongs_to :pos_transaction
  belongs_to :product_variant, optional: true
  belongs_to :product, optional: true
  belongs_to :sub_department, optional: true
  belongs_to :tax_category, optional: true
  belongs_to :store_tax_rate, optional: true
  belongs_to :source_transaction, class_name: "PosTransaction", optional: true
  belongs_to :source_transaction_line, class_name: "PosTransactionLine", optional: true

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :pos_transaction_id }
  validates :line_type, presence: true, inclusion: { in: LINE_TYPES }
  validates :quantity, presence: true, numericality: { only_integer: true, other_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :line_discount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :extended_price_cents, numericality: { only_integer: true }
  validates :tax_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :return_disposition, inclusion: { in: RETURN_DISPOSITIONS }, allow_nil: true
  validate :variant_required_for_variant_line
  validate :cannot_edit_when_transaction_locked, on: :update

  def variant_line?
    line_type == "variant"
  end

  def open_ring_line?
    line_type == "open_ring"
  end

  def return_line?
    quantity.negative?
  end

  def merchandise_line?
    variant_line? || open_ring_line?
  end

  private

  def variant_required_for_variant_line
    return unless variant_line?
    return if product_variant_id.present?

    errors.add(:product_variant, "must be present for variant lines")
  end

  def cannot_edit_when_transaction_locked
    return if pos_transaction.blank? || pos_transaction.editable?

    errors.add(:base, "cannot modify lines on a locked transaction")
  end
end
