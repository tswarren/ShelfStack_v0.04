# frozen_string_literal: true

class PurchaseOrder < ApplicationRecord
  include NestedLineRenumbering

  STATUSES = %w[draft submitted partially_received received cancelled closed].freeze
  ORDER_PURPOSES = %w[stock_order customer_direct_fulfillment mixed].freeze
  SHIP_TO_TYPES = %w[store customer third_party].freeze

  belongs_to :store
  belongs_to :vendor
  belongs_to :submitted_by_user, class_name: "User", optional: true

  has_many :purchase_order_lines, -> { order(:line_number) }, dependent: :destroy, inverse_of: :purchase_order
  has_many :purchase_order_line_demand_plans, dependent: :restrict_with_error
  has_many :receipts, dependent: :restrict_with_error

  accepts_nested_attributes_for :purchase_order_lines, allow_destroy: true, reject_if: :reject_blank_purchase_order_line?

  before_validation :normalize_line_numbers

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :order_purpose, presence: true, inclusion: { in: ORDER_PURPOSES }
  validates :ship_to_type, presence: true, inclusion: { in: SHIP_TO_TYPES }
  validate :store_must_be_active
  validate :vendor_must_be_active
  validate :reject_mixed_order_purpose
  validate :submitted_fields_locked_when_submitted, on: :update
  validate :cannot_edit_lines_when_submitted, on: :update

  scope :drafts, -> { where(status: "draft") }
  scope :submitted_records, -> { where.not(status: "draft") }

  OPEN_FOR_RECEIVE_LINE_STATUSES = %w[open partially_received backordered].freeze
  RECEIVABLE_PO_STATUSES = %w[submitted partially_received].freeze

  def draft?
    status == "draft"
  end

  def submitted?
    !draft? && status != "cancelled"
  end

  def receivable?
    return false if customer_direct?

    RECEIVABLE_PO_STATUSES.include?(status) && open_lines_for_receiving.any?
  end

  def customer_direct?
    ship_to_type == "customer" || order_purpose == "customer_direct_fulfillment"
  end

  def open_lines_for_receiving
    purchase_order_lines.select do |line|
      OPEN_FOR_RECEIVE_LINE_STATUSES.include?(line.status) &&
        Purchasing::PoLineQuantitySummary.for(line).open_to_receive_quantity.positive?
    end
  end

  def open_quantity_for_line(line)
    Purchasing::PoLineQuantitySummary.for(line).open_to_receive_quantity
  end

  private

  def reject_mixed_order_purpose
    return unless order_purpose == "mixed"

    errors.add(:order_purpose, "mixed purchase orders are not supported")
  end

  def store_must_be_active
    return if store.blank? || store.active?

    errors.add(:store, "must be active")
  end

  def vendor_must_be_active
    return if vendor.blank? || vendor.active?

    errors.add(:vendor, "must be active")
  end

  def submitted_fields_locked_when_submitted
    return if status_in_database == "draft"

    errors.add(:base, "cannot modify a submitted purchase order") if changed? && !only_status_changed?
  end

  def cannot_edit_lines_when_submitted
    return if status_in_database == "draft"

    errors.add(:base, "cannot modify lines on a submitted purchase order") if purchase_order_lines.any?(&:changed?)
  end

  def only_status_changed?
    (changes_to_save.keys - %w[updated_at]).sort == %w[status]
  end

  def reject_blank_purchase_order_line?(attributes)
    return false if ActiveModel::Type::Boolean.new.cast(attributes["_destroy"])
    return false if attributes["id"].present?

    attributes["product_variant_id"].blank?
  end

  def normalize_line_numbers
    return unless draft?

    renumber_nested_lines(purchase_order_lines)
  end
end
