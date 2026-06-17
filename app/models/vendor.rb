# frozen_string_literal: true

class Vendor < ApplicationRecord
  belongs_to :parent_vendor, class_name: "Vendor", optional: true
  has_many :child_vendors, class_name: "Vendor", foreign_key: :parent_vendor_id, dependent: :restrict_with_error,
           inverse_of: :parent_vendor
  has_many :product_vendors, dependent: :restrict_with_error
  has_many :product_variant_vendors, dependent: :restrict_with_error
  has_many :vendor_terms, dependent: :restrict_with_error
  has_many :purchase_orders, dependent: :restrict_with_error
  has_many :receipts, dependent: :restrict_with_error
  has_many :returns_to_vendor, class_name: "ReturnToVendor", dependent: :restrict_with_error

  validates :name, presence: true
  validates :default_supplier_discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validate :parent_vendor_must_be_active

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_strings
    self.name = name&.strip
  end

  def parent_vendor_must_be_active
    return if parent_vendor.blank? || parent_vendor.active?

    errors.add(:parent_vendor, "must be active")
  end
end
