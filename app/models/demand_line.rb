# frozen_string_literal: true

class DemandLine < ApplicationRecord
  SOURCES = %w[
    customer_order
    manual_tbo
    sales_replenishment
    buyer_decision
    frontlist_import
    promotion
    event
    inventory_replacement
    used_wanted_request
  ].freeze

  PURPOSES = %w[
    customer_fulfillment
    shelf_replenishment
    frontlist_stock
    display_stock
    event_stock
    preorder_fulfillment
    backorder_fulfillment
    replacement
    used_wanted
  ].freeze

  CAPTURE_INTENTS = %w[
    hold
    notify
    special_order
    research
    manual_tbo
    used_wanted
    buyer_replenishment
  ].freeze

  STATUSES = %w[captured open partially_allocated allocated fulfilled canceled expired].freeze

  TERMINAL_STATUSES = %w[fulfilled canceled expired].freeze

  ALLOCATION_ACTIVE_STATUSES = %w[open partially_allocated allocated].freeze

  PREFERRED_CONTACT_METHODS = Customer::PREFERRED_CONTACT_METHODS

  belongs_to :store
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  belongs_to :customer, optional: true
  belongs_to :created_by_user, class_name: "User"
  belongs_to :matched_by_user, class_name: "User", optional: true
  belongs_to :canceled_by_user, class_name: "User", optional: true
  belongs_to :expired_by_user, class_name: "User", optional: true
  belongs_to :stock_consideration, optional: true

  has_many :demand_allocations, dependent: :restrict_with_error

  validates :demand_number, presence: true, uniqueness: { scope: :store_id }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :purpose, presence: true, inclusion: { in: PURPOSES }
  validates :capture_intent, inclusion: { in: CAPTURE_INTENTS }, allow_blank: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quantity_requested, numericality: { only_integer: true, greater_than: 0 }
  validates :preferred_contact_method, inclusion: { in: PREFERRED_CONTACT_METHODS }, allow_blank: true
  validate :product_variant_consistency
  validate :open_status_requires_variant
  validate :customer_or_snapshot_present, if: -> { capture_intent_requires_customer? }
  validate :special_order_requires_customer_record, if: -> { capture_intent == "special_order" }

  scope :open_lines, -> { where(status: "open") }
  scope :active_lines, -> { where.not(status: TERMINAL_STATUSES) }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def display_customer_name
    customer&.display_name || customer_name_snapshot
  end

  private

  def product_variant_consistency
    return if product_variant_id.blank?

    if product_id.blank?
      errors.add(:product_id, "must be present when variant is set")
      return
    end

    return if product_variant.product_id == product_id

    errors.add(:product_id, "must match product_variant.product_id")
  end

  def open_status_requires_variant
    return unless ALLOCATION_ACTIVE_STATUSES.include?(status) || status == "open"
    return if product_variant_id.present?

    errors.add(:product_variant, "must be present when status is #{status}")
  end

  def capture_intent_requires_customer?
    %w[hold notify special_order used_wanted research].include?(capture_intent)
  end

  def customer_or_snapshot_present
    return if customer_id.present?
    return if customer_name_snapshot.present?

    errors.add(:base, "Customer or walk-in name is required")
  end

  def special_order_requires_customer_record
    return if customer_id.present?

    errors.add(:customer, "is required for special orders")
  end
end
