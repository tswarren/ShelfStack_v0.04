# frozen_string_literal: true

class ReturnToVendor < ApplicationRecord
  include NestedLineRenumbering

  self.table_name = "returns_to_vendor"

  STATUSES = %w[draft posted cancelled credited closed].freeze

  belongs_to :store
  belongs_to :vendor
  belongs_to :posted_by_user, class_name: "User", optional: true
  belongs_to :inventory_posting, optional: true

  has_many :return_to_vendor_lines, -> { order(:line_number) }, dependent: :destroy, inverse_of: :return_to_vendor

  accepts_nested_attributes_for :return_to_vendor_lines, allow_destroy: true, reject_if: :reject_blank_return_to_vendor_line?

  before_validation :normalize_line_numbers

  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :store_must_be_active
  validate :vendor_must_be_active
  validate :posted_fields_locked_when_posted, on: :update
  validate :cannot_edit_when_posted, on: :update

  scope :drafts, -> { where(status: "draft") }

  def draft?
    status == "draft"
  end

  def posted?
    %w[posted credited closed].include?(status)
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

  def posted_fields_locked_when_posted
    return unless status_in_database == "posted"

    errors.add(:base, "cannot modify a posted return to vendor") if changed?
  end

  def cannot_edit_when_posted
    return unless %w[posted credited closed].include?(status_in_database)

    errors.add(:base, "posted returns to vendor are immutable")
  end

  def reject_blank_return_to_vendor_line?(attributes)
    return false if ActiveModel::Type::Boolean.new.cast(attributes["_destroy"])
    return false if attributes["id"].present?

    attributes["product_variant_id"].blank?
  end

  def normalize_line_numbers
    return if posted?

    renumber_nested_lines(return_to_vendor_lines)
  end
end
