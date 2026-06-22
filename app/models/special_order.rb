# frozen_string_literal: true

class SpecialOrder < ApplicationRecord
  STATUSES = %w[
    pending_match approved ordered partially_received ready_for_pickup completed cancelled unfillable
  ].freeze

  belongs_to :store
  belongs_to :customer
  belongs_to :customer_request_line
  belongs_to :product_variant, optional: true
  belongs_to :vendor, optional: true
  belongs_to :created_by_user, class_name: "User"

  has_many :inventory_reservations, dependent: :restrict_with_error
  has_many :purchase_order_line_allocations, dependent: :restrict_with_error
  has_many :receipt_line_allocations, dependent: :restrict_with_error

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quantity_committed, numericality: { only_integer: true, greater_than: 0 }
  validates :quantity_ordered, :quantity_received, :quantity_ready, :quantity_completed, :quantity_cancelled,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :customer_request_line_id, uniqueness: true
  validate :store_matches_request_line
  validate :customer_matches_request

  scope :open_orders, -> { where.not(status: %w[completed cancelled unfillable]) }

  def remaining_committed
    quantity_committed - quantity_completed - quantity_cancelled
  end

  private

  def store_matches_request_line
    return if customer_request_line.blank? || store_id.blank?
    return if customer_request_line.customer_request.store_id == store_id

    errors.add(:store, "must match customer request store")
  end

  def customer_matches_request
    return if customer_request_line.blank? || customer_id.blank?

    request_customer_id = customer_request_line.customer_request.customer_id
    return if request_customer_id.blank? || request_customer_id == customer_id

    errors.add(:customer, "must match customer request customer")
  end
end
