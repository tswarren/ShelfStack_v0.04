# frozen_string_literal: true

class ReturnToVendorLine < ApplicationRecord
  belongs_to :return_to_vendor
  belongs_to :product_variant

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :return_to_vendor_id }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :supplier_discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validates :credit_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :return_to_vendor_must_be_draft, on: :update
  validate :product_variant_must_be_active

  before_validation :assign_line_number, on: :create

  private

  def assign_line_number
    return if line_number.present? || return_to_vendor.blank?

    siblings = return_to_vendor.return_to_vendor_lines.to_a.reject do |line|
      line.marked_for_destruction? || line == self
    end
    used_numbers = siblings.filter_map(&:line_number)
    persisted_max = return_to_vendor.return_to_vendor_lines.where.not(id: id).maximum(:line_number) || 0
    self.line_number = [ persisted_max, used_numbers.max || 0 ].max + 1
  end

  def return_to_vendor_must_be_draft
    return if return_to_vendor.blank? || return_to_vendor.draft?

    errors.add(:base, "cannot modify lines on a non-draft return to vendor")
  end

  def product_variant_must_be_active
    return if product_variant.blank? || product_variant.active?

    errors.add(:product_variant, "must be active")
  end
end
