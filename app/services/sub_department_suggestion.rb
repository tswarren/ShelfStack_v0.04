# frozen_string_literal: true

class SubDepartmentSuggestion
  CONDITION_KEY_MAP = {
    "used_like_new" => "used_books",
    "used_very_good" => "used_books",
    "used_good" => "used_books",
    "used_acceptable" => "used_books",
    "remainder" => "general_trade_books"
  }.freeze

  Result = Data.define(:sub_department, :source)

  def self.for(product:, condition: nil)
    new(product: product, condition: condition).call
  end

  def initialize(product:, condition: nil)
    @product = product
    @condition = condition
  end

  def call
    from_explicit = product.default_sub_department
    return Result.new(sub_department: from_explicit, source: "product_default") if from_explicit.present?

    from_store_category = store_category_default_sub_department
    return Result.new(sub_department: from_store_category, source: "store_category_default") if from_store_category.present?

    from_condition = condition_suggested_sub_department
    return Result.new(sub_department: from_condition, source: "condition_suggestion") if from_condition.present?

    Result.new(sub_department: nil, source: "none")
  end

  private

  attr_reader :product, :condition

  def store_category_default_sub_department
    product.catalog_item&.store_category&.default_sub_department
  end

  def condition_suggested_sub_department
    return if condition.blank?

    key = CONDITION_KEY_MAP[condition.condition_key]
    return if key.blank?

    SubDepartment.active_records.find_by(sub_department_key: key)
  end
end
