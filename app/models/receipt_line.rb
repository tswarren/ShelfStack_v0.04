# frozen_string_literal: true

class ReceiptLine < ApplicationRecord
  include NestedLineNumberUniqueness

  belongs_to :receipt
  belongs_to :product_variant
  belongs_to :purchase_order_line, optional: true

  has_many :receiving_discrepancies, dependent: :destroy

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates_nested_line_number_uniqueness :receipt, foreign_key: :receipt_id
  validates :quantity_expected, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quantity_received, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quantity_accepted, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quantity_rejected, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :supplier_discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validate :receipt_must_be_draft, on: :update
  validate :product_variant_must_be_active
  validate :accepted_plus_rejected_cannot_exceed_received
  validate :purchase_order_line_must_match

  before_validation :assign_line_number, on: :create
  before_validation :reconcile_quantities, if: :receipt_draft?
  before_validation :apply_price_defaults, if: :receipt_draft?

  private

  def receipt_draft?
    receipt&.draft?
  end

  def apply_price_defaults
    Purchasing::LinePriceDefaults.apply!(self)
  end

  def reconcile_quantities
    return if quantity_received.nil?

    received = quantity_received.to_i
    self.quantity_rejected = quantity_rejected.to_i.clamp(0, received)
    max_accepted = received - quantity_rejected
    accepted = quantity_accepted.to_i

    if accepted > max_accepted
      self.quantity_accepted = max_accepted
    elsif accepted.zero? && max_accepted.positive?
      self.quantity_accepted = max_accepted
    end
  end

  def assign_line_number
    return if line_number.present? || receipt.blank?

    siblings = receipt.receipt_lines.to_a.reject do |line|
      line.marked_for_destruction? || line == self
    end
    used_numbers = siblings.filter_map(&:line_number)
    persisted_max = receipt.receipt_lines.where.not(id: id).maximum(:line_number) || 0
    self.line_number = [ persisted_max, used_numbers.max || 0 ].max + 1
  end

  def receipt_must_be_draft
    return if receipt.blank? || receipt.draft?

    errors.add(:base, "cannot modify lines on a non-draft receipt")
  end

  def product_variant_must_be_active
    return if product_variant.blank? || product_variant.active?

    errors.add(:product_variant, "must be active")
  end

  def accepted_plus_rejected_cannot_exceed_received
    return if quantity_accepted.blank? || quantity_rejected.blank? || quantity_received.blank?

    if quantity_accepted + quantity_rejected > quantity_received
      errors.add(:base, "accepted and rejected quantities cannot exceed received quantity")
    end
  end

  def purchase_order_line_must_match
    return if purchase_order_line.blank? || product_variant.blank?

    if purchase_order_line.product_variant_id != product_variant_id
      errors.add(:purchase_order_line, "must reference the same product variant")
    end
  end
end
