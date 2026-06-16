# frozen_string_literal: true

class AccountingMapping < ApplicationRecord
  belongs_to :sub_department, optional: true
  belongs_to :condition, class_name: "ProductCondition", optional: true
  belongs_to :category_node, optional: true

  validates :sales_account_code, presence: true, length: { maximum: 20 }
  validates :reporting_bucket, length: { maximum: 50 }, allow_blank: true
  validates :gl_export_code, length: { maximum: 20 }, allow_blank: true
  validates :product_type, inclusion: { in: Product::PRODUCT_TYPES }, allow_blank: true
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :at_least_one_match_dimension
  validate :referenced_records_must_be_active

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def specificity_score
    [sub_department_id, condition_id, product_type, category_node_id].compact.size
  end

  private

  def normalize_strings
    self.sales_account_code = sales_account_code&.strip
    self.reporting_bucket = reporting_bucket&.strip.presence
    self.gl_export_code = gl_export_code&.strip.presence
    self.description = description&.strip.presence
    self.product_type = product_type&.strip.presence
  end

  def at_least_one_match_dimension
    return if sub_department_id.present? || condition_id.present? || product_type.present? || category_node_id.present?

    errors.add(:base, "At least one match dimension is required")
  end

  def referenced_records_must_be_active
    errors.add(:sub_department, "must be active") if sub_department.present? && !sub_department.active?
    errors.add(:condition, "must be active") if condition.present? && !condition.active?
    errors.add(:category_node, "must be active") if category_node.present? && !category_node.active?
  end
end
