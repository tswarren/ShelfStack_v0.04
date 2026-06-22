# frozen_string_literal: true

class PurchaseOrderLineAllocation < ApplicationRecord
  STATUSES = %w[active partially_received received cancelled closed_short].freeze

  belongs_to :purchase_order_line
  belongs_to :special_order
  belongs_to :customer_request_line, optional: true

  validates :quantity_allocated, numericality: { only_integer: true, greater_than: 0 }
  validates :quantity_received, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :open_allocations, -> { where(status: %w[active partially_received]) }
  validate :customer_request_line_matches_special_order
  validate :quantity_received_within_allocated

  private

  def customer_request_line_matches_special_order
    return if customer_request_line_id.blank?
    return if customer_request_line_id == special_order.customer_request_line_id

    errors.add(:customer_request_line, "must match special order request line")
  end

  def quantity_received_within_allocated
    return if quantity_received <= quantity_allocated

    errors.add(:quantity_received, "cannot exceed quantity allocated")
  end
end
