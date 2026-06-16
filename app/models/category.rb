# frozen_string_literal: true

class Category < ApplicationRecord
  include PricingModels

  PRICING_MODELS = PricingModels::PRICING_MODELS

  belongs_to :department
  belongs_to :sub_department, optional: true
  belongs_to :default_tax_category, class_name: "TaxCategory"

  validates :name, presence: true, uniqueness: { scope: :department_id }
  validates :short_name, presence: true, uniqueness: { scope: :department_id }, length: { maximum: 20 }
  validates :sort_order, numericality: { only_integer: true }
  validates :default_pricing_model, inclusion: { in: PRICING_MODELS }, allow_blank: true
  validates :default_margin_target_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validates :default_supplier_discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validate :department_must_be_active
  validate :default_tax_category_must_be_active
  validate :sub_department_department_must_match

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
    self.short_name = short_name&.strip
  end

  def department_must_be_active
    return if department.blank? || department.active?

    errors.add(:department, "must be active")
  end

  def default_tax_category_must_be_active
    return if default_tax_category.blank? || default_tax_category.active?

    errors.add(:default_tax_category, "must be active")
  end

  def sub_department_department_must_match
    return if sub_department.blank? || department.blank?
    return if sub_department.department_id == department_id

    errors.add(:sub_department, "must belong to the same department")
  end
end
