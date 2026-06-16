# frozen_string_literal: true

class InventoryAdjustmentLine < ApplicationRecord
  belongs_to :inventory_adjustment
  belongs_to :product_variant
  belongs_to :inventory_location, optional: true
  belongs_to :inventory_reason_code, optional: true

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :inventory_adjustment_id }
  validates :quantity_delta, presence: true, numericality: { only_integer: true }
  validates :unit_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :adjustment_must_be_draft, on: :update
  validate :product_variant_must_be_active
  validate :inventory_location_must_be_active
  validate :inventory_reason_code_must_be_active

  before_validation :assign_line_number, on: :create

  private

  def assign_line_number
    return if line_number.present? || inventory_adjustment.blank?

    max_line = inventory_adjustment.inventory_adjustment_lines.where.not(id: id).maximum(:line_number) || 0
    self.line_number = max_line + 1
  end

  def adjustment_must_be_draft
    return if inventory_adjustment.blank? || inventory_adjustment.draft?

    errors.add(:base, "cannot modify lines on a non-draft adjustment")
  end

  def product_variant_must_be_active
    return if product_variant.blank? || product_variant.active?

    errors.add(:product_variant, "must be active")
  end

  def inventory_location_must_be_active
    return if inventory_location.blank? || inventory_location.active?

    errors.add(:inventory_location, "must be active")
  end

  def inventory_reason_code_must_be_active
    return if inventory_reason_code.blank? || inventory_reason_code.active?

    errors.add(:inventory_reason_code, "must be active")
  end
end
