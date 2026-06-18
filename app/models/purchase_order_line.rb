# frozen_string_literal: true

class PurchaseOrderLine < ApplicationRecord
  include NestedLineNumberUniqueness

  STATUSES = %w[open partially_received received backordered cancelled closed_short closed].freeze

  belongs_to :purchase_order
  belongs_to :product_variant
  belongs_to :vendor
  belongs_to :product_variant_vendor, optional: true
  belongs_to :purchase_request_line, optional: true

  has_many :receipt_lines, dependent: :restrict_with_error

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates_nested_line_number_uniqueness :purchase_order, foreign_key: :purchase_order_id
  validates :quantity_ordered, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :quantity_received, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :supplier_discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validates :returnability_status_snapshot,
            inclusion: { in: ReturnabilityStatus::RETURNABILITY_STATUSES },
            allow_nil: true
  validate :purchase_order_must_be_draft, on: :update, unless: :operational_line_update?
  validate :product_variant_must_be_active
  validate :vendor_must_be_active
  validate :quantity_received_cannot_exceed_ordered

  before_validation :assign_line_number, on: :create
  before_validation :apply_price_defaults, if: :draft_purchase_order_line?

  attr_accessor :receiving_update, :closure_update

  def receiving_update?
    receiving_update == true
  end

  def closure_update?
    closure_update == true
  end

  def operational_line_update?
    receiving_update? || closure_update?
  end

  private

  def draft_purchase_order_line?
    purchase_order&.draft?
  end

  def apply_price_defaults
    self.vendor = purchase_order.vendor if vendor.blank? && purchase_order&.vendor.present?
    Purchasing::LinePriceDefaults.apply!(self)
  end

  def assign_line_number
    return if line_number.present? || purchase_order.blank?

    siblings = purchase_order.purchase_order_lines.to_a.reject do |line|
      line.marked_for_destruction? || line == self
    end
    used_numbers = siblings.filter_map(&:line_number)
    persisted_max = purchase_order.purchase_order_lines.where.not(id: id).maximum(:line_number) || 0
    self.line_number = [ persisted_max, used_numbers.max || 0 ].max + 1
  end

  def purchase_order_must_be_draft
    return if purchase_order.blank? || purchase_order.draft?

    errors.add(:base, "cannot modify lines on a non-draft purchase order")
  end

  def product_variant_must_be_active
    return if product_variant.blank? || product_variant.active?

    errors.add(:product_variant, "must be active")
  end

  def vendor_must_be_active
    return if vendor.blank? || vendor.active?

    errors.add(:vendor, "must be active")
  end

  def quantity_received_cannot_exceed_ordered
    return if quantity_received.blank? || quantity_ordered.blank?
    return if quantity_received <= quantity_ordered

    errors.add(:quantity_received, "cannot exceed quantity ordered")
  end
end
