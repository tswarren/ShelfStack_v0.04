# frozen_string_literal: true

class VendorTerm < ApplicationRecord
  belongs_to :vendor

  validates :name, presence: true, uniqueness: { scope: :vendor_id }
  validates :net_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :vendor_must_be_active

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
end
