# frozen_string_literal: true

class PurchaseRequestLine < ApplicationRecord
  include NestedLineNumberUniqueness

  STATUSES = %w[
    open sourcing_needed ready_to_order added_to_po partially_ordered cancelled closed
  ].freeze

  belongs_to :purchase_request
  belongs_to :product_variant
  has_one :purchase_order_line, dependent: :nullify

  validates :line_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates_nested_line_number_uniqueness :purchase_request, foreign_key: :purchase_request_id
  validates :requested_quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :product_variant_must_be_active

  before_validation :assign_line_number, on: :create

  scope :buildable, -> { where(status: PurchaseRequest::BUILDABLE_LINE_STATUSES) }

  scope :buildable_for_store, lambda { |store|
    buildable
      .joins(:purchase_request)
      .where(purchase_requests: { store_id: store.id })
      .where.not(purchase_requests: { status: PurchaseRequest::CLOSED_STATUSES })
  }

  def ordered_quantity
    self.class.ordered_quantities_for([ id ]).fetch(id, 0)
  end

  def remaining_quantity
    requested_quantity - ordered_quantity
  end

  def self.ordered_quantities_for(line_ids)
    return {} if line_ids.blank?

    PurchaseOrderLine
      .joins(:purchase_order)
      .where(purchase_request_line_id: line_ids)
      .where.not(purchase_orders: { status: "cancelled" })
      .group(:purchase_request_line_id)
      .sum(:quantity_ordered)
  end

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
