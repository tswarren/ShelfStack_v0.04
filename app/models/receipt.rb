# frozen_string_literal: true

class Receipt < ApplicationRecord
  include NestedLineRenumbering

  RECEIPT_TYPES = %w[po_backed direct].freeze
  STATUSES = %w[draft posted cancelled].freeze

  belongs_to :store
  belongs_to :vendor
  belongs_to :purchase_order, optional: true
  belongs_to :posted_by_user, class_name: "User", optional: true
  belongs_to :inventory_posting, optional: true

  has_many :receipt_lines, -> { order(:line_number) }, dependent: :destroy, inverse_of: :receipt

  accepts_nested_attributes_for :receipt_lines, allow_destroy: true, reject_if: :reject_blank_receipt_line?

  before_validation :normalize_line_numbers

  validates :receipt_type, presence: true, inclusion: { in: RECEIPT_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :store_must_be_active
  validate :vendor_must_be_active
  validate :purchase_order_must_match_vendor
  validate :posted_fields_locked_when_posted, on: :update
  validate :cannot_edit_when_posted, on: :update

  scope :drafts, -> { where(status: "draft") }

  def draft?
    status == "draft"
  end

  def posted?
    status == "posted"
  end

  def po_backed?
    receipt_type == "po_backed"
  end

  private

  def store_must_be_active
    return if store.blank? || store.active?

    errors.add(:store, "must be active")
  end

  def vendor_must_be_active
    return if vendor.blank? || vendor.active?

    errors.add(:vendor, "must be active")
  end

  def purchase_order_must_match_vendor
    return if purchase_order.blank?

    errors.add(:purchase_order, "must belong to the same vendor") if purchase_order.vendor_id != vendor_id
    errors.add(:purchase_order, "must belong to the same store") if purchase_order.store_id != store_id
  end

  def posted_fields_locked_when_posted
    return unless status_in_database == "posted"

    errors.add(:base, "cannot modify a posted receipt") if changed?
  end

  def cannot_edit_when_posted
    return unless status_in_database == "posted"

    errors.add(:base, "posted receipts are immutable")
  end

  def normalize_line_numbers
    return if posted?

    renumber_nested_lines(receipt_lines)
  end

  def reject_blank_receipt_line?(attributes)
    return false if ActiveModel::Type::Boolean.new.cast(attributes["_destroy"])
    return false if attributes["id"].present?

    attributes["product_variant_id"].blank?
  end
end
