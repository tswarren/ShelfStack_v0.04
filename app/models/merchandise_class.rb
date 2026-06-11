# frozen_string_literal: true

class MerchandiseClass < ApplicationRecord
  include PricingModels

  has_many :categories, dependent: :restrict_with_error
  has_many :accounting_mappings, dependent: :restrict_with_error

  belongs_to :default_tax_category, class_name: "TaxCategory"

  validates :merchandise_class_key, presence: true, uniqueness: true, length: { maximum: 30 }
  validates :name, presence: true, uniqueness: true
  validates :short_name, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :default_pricing_model, inclusion: { in: PRICING_MODELS }, allow_blank: true
  validates :default_margin_target_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validates :default_supplier_discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validates :default_sales_account_code, length: { maximum: 20 }, allow_blank: true
  validate :default_tax_category_must_be_active

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
    self.merchandise_class_key = merchandise_class_key&.strip&.downcase
    self.name = name&.strip
    self.short_name = short_name&.strip
    self.default_sales_account_code = default_sales_account_code&.strip.presence
  end

  def default_tax_category_must_be_active
    return if default_tax_category.blank? || default_tax_category.active?

    errors.add(:default_tax_category, "must be active")
  end
end
