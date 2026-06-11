# frozen_string_literal: true

class Vendor < ApplicationRecord
  belongs_to :parent_vendor, class_name: "Vendor", optional: true
  has_many :child_vendors, class_name: "Vendor", foreign_key: :parent_vendor_id, dependent: :restrict_with_error,
           inverse_of: :parent_vendor

  validates :name, presence: true
  validates :default_pricing_model, inclusion: { in: Category::PRICING_MODELS }, allow_blank: true
  validates :default_margin_target_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
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
