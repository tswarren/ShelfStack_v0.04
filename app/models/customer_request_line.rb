# frozen_string_literal: true

class CustomerRequestLine < ApplicationRecord
  REQUEST_TYPES = %w[research notify hold special_order].freeze

  STATUSES = %w[
    new researching matched awaiting_customer_response approved ordered
    partially_filled ready_for_pickup completed cancelled unfillable
  ].freeze

  belongs_to :customer_request
  belongs_to :catalog_item, optional: true
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  has_one :special_order, dependent: :restrict_with_error
  has_many :inventory_reservations, dependent: :restrict_with_error
  has_many :purchase_order_line_allocations, dependent: :restrict_with_error
  has_many :receipt_line_allocations, dependent: :restrict_with_error
  has_many :customer_contact_events, dependent: :destroy

  validates :line_number, presence: true, uniqueness: { scope: :customer_request_id }
  validates :request_type, presence: true, inclusion: { in: REQUEST_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :requested_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :approved_quantity, :ordered_quantity, :filled_quantity, :cancelled_quantity,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quoted_price_cents, :max_customer_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :variant_required_for_fulfillment_types

  delegate :store, to: :customer_request

  scope :open_lines, -> { where.not(status: %w[completed cancelled unfillable]) }

  after_initialize :apply_line_defaults, if: :new_record?

  def remaining_quantity
    requested_quantity - filled_quantity - cancelled_quantity
  end

  def matched?
    product_variant_id.present?
  end

  private

  def apply_line_defaults
    self.request_type = "research" if request_type.blank?
    self.requested_quantity = 1 if requested_quantity.blank?
    self.status = "new" if status.blank?
  end

  def variant_required_for_fulfillment_types
    return if %w[research].include?(request_type)
    return if product_variant_id.present?
    return if %w[new researching].include?(status)

    errors.add(:product_variant, "must be matched before #{request_type} fulfillment")
  end
end
