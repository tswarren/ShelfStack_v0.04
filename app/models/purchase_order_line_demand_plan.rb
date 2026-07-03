# frozen_string_literal: true

class PurchaseOrderLineDemandPlan < ApplicationRecord
  FULFILLMENT_ROUTES = %w[inbound_to_store vendor_direct_to_customer].freeze
  COVERAGE_KINDS = %w[
    customer_fulfillment shelf_replenishment frontlist_stock display_stock
    event_stock preorder_fulfillment backorder_fulfillment replacement other
  ].freeze
  STATUSES = %w[planned partially_converted converted released canceled superseded].freeze
  ACTIVE_STATUSES = %w[planned partially_converted].freeze

  belongs_to :store
  belongs_to :purchase_order
  belongs_to :purchase_order_line
  belongs_to :demand_line
  belongs_to :product
  belongs_to :product_variant
  belongs_to :created_by_user, class_name: "User"
  belongs_to :converted_to_demand_allocation, class_name: "DemandAllocation", optional: true
  belongs_to :converted_by_user, class_name: "User", optional: true
  belongs_to :released_by_user, class_name: "User", optional: true

  validates :quantity_planned, numericality: { only_integer: true, greater_than: 0 }
  validates :fulfillment_route, inclusion: { in: FULFILLMENT_ROUTES }
  validates :coverage_kind, inclusion: { in: COVERAGE_KINDS }
  validates :status, inclusion: { in: STATUSES }
  validate :consistency_across_records
  validate :draft_purchase_order_only, on: :create

  scope :active_plans, -> { where(status: ACTIVE_STATUSES) }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def inbound_to_store?
    fulfillment_route == "inbound_to_store"
  end

  private

  def consistency_across_records
    if demand_line.present?
      errors.add(:store, "must match demand line store") if store_id != demand_line.store_id
      errors.add(:product_variant, "must match demand line variant") if product_variant_id != demand_line.product_variant_id
      errors.add(:product, "must match demand line product") if product_id != demand_line.product_id
    end

    if purchase_order_line.present?
      errors.add(:product_variant, "must match PO line variant") if product_variant_id != purchase_order_line.product_variant_id
    end
  end

  def draft_purchase_order_only
    return if purchase_order.blank? || purchase_order.draft?

    errors.add(:purchase_order, "must be draft for new planned coverage")
  end
end
