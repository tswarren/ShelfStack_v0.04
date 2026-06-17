# frozen_string_literal: true

class PurchaseRequestLine < ApplicationRecord
  STATUSES = %w[
    open sourcing_needed ready_to_order added_to_po partially_ordered cancelled closed
  ].freeze

  belongs_to :purchase_request
  belongs_to :product_variant

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :purchase_request_id }
  validates :requested_quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :product_variant_must_be_active

  before_validation :assign_line_number, on: :create

  private

  def assign_line_number
    return if line_number.present? || purchase_request.blank?

    siblings = purchase_request.purchase_request_lines.to_a.reject do |line|
      line.marked_for_destruction? || line == self
    end
    used_numbers = siblings.filter_map(&:line_number)
    persisted_max = purchase_request.purchase_request_lines.where.not(id: id).maximum(:line_number) || 0
    self.line_number = [ persisted_max, used_numbers.max || 0 ].max + 1
  end

  def product_variant_must_be_active
    return if product_variant.blank? || product_variant.active?

    errors.add(:product_variant, "must be active")
  end
end
