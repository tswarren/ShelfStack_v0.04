# frozen_string_literal: true

class DemandAllocation < ApplicationRecord
  ALLOCATION_KINDS = %w[on_hand inbound_purchase_order vendor_backorder vendor_direct_fulfillment].freeze
  STATUSES = %w[active fulfilled released expired canceled converted].freeze
  ACTIVE_STATUS = "active".freeze
  TERMINAL_STATUSES = %w[fulfilled released expired canceled converted].freeze

  belongs_to :store
  belongs_to :demand_line
  belongs_to :product
  belongs_to :product_variant
  belongs_to :purchase_order_line, optional: true
  belongs_to :sourcing_attempt, optional: true
  belongs_to :vendor_response, optional: true
  belongs_to :allocated_by_user, class_name: "User"
  belongs_to :released_by_user, class_name: "User", optional: true
  belongs_to :canceled_by_user, class_name: "User", optional: true
  belongs_to :expired_by_user, class_name: "User", optional: true
  belongs_to :fulfilled_by_user, class_name: "User", optional: true
  belongs_to :override_authorized_by_user, class_name: "User", optional: true
  belongs_to :converted_from_allocation, class_name: "DemandAllocation", optional: true
  belongs_to :converted_to_allocation, class_name: "DemandAllocation", optional: true
  belongs_to :conversion_receipt_line, class_name: "ReceiptLine", optional: true
  belongs_to :conversion_purchase_order_line, class_name: "PurchaseOrderLine", optional: true
  belongs_to :converted_by_user, class_name: "User", optional: true

  validates :allocation_kind, presence: true, inclusion: { in: ALLOCATION_KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quantity_allocated, numericality: { only_integer: true, greater_than: 0 }
  validates :allocated_at, presence: true
  validate :demand_line_consistency
  validate :purchase_order_line_consistency
  validate :override_fields_when_flagged
  validate :terminal_status_fields

  scope :active_allocations, -> { where(status: ACTIVE_STATUS) }
  scope :on_hand_kind, -> { where(allocation_kind: "on_hand") }
  scope :inbound_kind, -> { where(allocation_kind: "inbound_purchase_order") }
  scope :vendor_backorder_kind, -> { where(allocation_kind: "vendor_backorder") }

  def active?
    status == ACTIVE_STATUS
  end

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def on_hand?
    allocation_kind == "on_hand"
  end

  def vendor_backorder?
    allocation_kind == "vendor_backorder"
  end

  private

  def demand_line_consistency
    return if demand_line.blank?

    if store_id.present? && demand_line.store_id != store_id
      errors.add(:store, "must match demand line store")
    end

    if product_variant_id.present? && demand_line.product_variant_id != product_variant_id
      errors.add(:product_variant, "must match demand line variant")
    end

    if product_id.present? && product_variant.present? && product_id != product_variant.product_id
      errors.add(:product_id, "must match product variant product")
    end

    if product_id.present? && demand_line.product_id.present? && demand_line.product_id != product_id
      errors.add(:product_id, "must match demand line product")
    end
  end

  def purchase_order_line_consistency
    case allocation_kind
    when "inbound_purchase_order"
      errors.add(:purchase_order_line, "is required for inbound allocation") if purchase_order_line_id.blank?
    when "vendor_backorder"
      errors.add(:purchase_order_line, "must be blank for vendor backorder allocation") if purchase_order_line_id.present?
      if sourcing_attempt_id.blank? && vendor_response_id.blank?
        errors.add(:base, "vendor backorder allocation requires sourcing attempt or vendor response")
      end
    when "on_hand"
      errors.add(:purchase_order_line, "must be blank for on-hand allocation") if purchase_order_line_id.present?
    when "vendor_direct_fulfillment"
      errors.add(:purchase_order_line, "is required for vendor-direct fulfillment") if purchase_order_line_id.blank?
    end
  end

  def override_fields_when_flagged
    return unless override_availability?

    if allocation_kind != "on_hand"
      errors.add(:override_availability, "is only allowed for on-hand allocations")
      return
    end

    errors.add(:override_authorized_by_user, "is required when overriding availability") if override_authorized_by_user_id.blank?
    errors.add(:override_authorized_at, "is required when overriding availability") if override_authorized_at.blank?
    errors.add(:override_reason, "is required when overriding availability") if override_reason.blank?
  end

  def terminal_status_fields
    case status
    when "released"
      errors.add(:released_at, "is required") if released_at.blank?
      errors.add(:released_by_user, "is required") if released_by_user_id.blank?
    when "canceled"
      errors.add(:canceled_at, "is required") if canceled_at.blank?
      errors.add(:canceled_by_user, "is required") if canceled_by_user_id.blank?
      errors.add(:cancel_reason, "is required") if cancel_reason.blank?
    when "expired"
      errors.add(:expired_at, "is required") if expired_at.blank?
    when "fulfilled"
      errors.add(:fulfilled_at, "is required") if fulfilled_at.blank?
      if fulfilled_by_user_id.blank? && fulfillment_reference_type.blank?
        errors.add(:base, "fulfilled_by_user or fulfillment reference is required")
      end
    when "converted"
      errors.add(:converted_at, "is required") if converted_at.blank?
      errors.add(:converted_by_user, "is required") if converted_by_user_id.blank?
      errors.add(:conversion_receipt_line, "is required") if conversion_receipt_line_id.blank?
      errors.add(:converted_to_allocation, "is required") if converted_to_allocation_id.blank?
    end
  end
end
