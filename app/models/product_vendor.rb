# frozen_string_literal: true

class ProductVendor < ApplicationRecord
  include ReturnabilityStatus

  belongs_to :product
  belongs_to :vendor

  validates :supplier_discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validates :product_id, uniqueness: { scope: :vendor_id }
  validate :vendor_must_be_active
  validate :product_must_be_active

  scope :active_records, -> { where(active: true) }

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def vendor_must_be_active
    return if vendor.blank? || vendor.active?

    errors.add(:vendor, "must be active")
  end

  def product_must_be_active
    return if product.blank? || product.active?

    errors.add(:product, "must be active")
  end
end
