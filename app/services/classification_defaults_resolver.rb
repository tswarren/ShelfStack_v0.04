# frozen_string_literal: true

class ClassificationDefaultsResolver
  Result = Data.define(
    :pricing_model,
    :margin_target_bps,
    :supplier_discount_bps,
    :tax_category,
    :sales_account_code,
    :reporting_bucket,
    :returnable,
    :buyback_allowed,
    :has_list_price,
    :source,
    :warnings
  )

  def self.for(variant:, store: nil, date: Date.current)
    new(variant: variant, store: store, date: date).call
  end

  def initialize(variant:, store: nil, date: Date.current)
    @variant = variant
    @store = store
    @date = date.to_date
    @warnings = []
  end

  def call
    if variant.pricing_model_override.present?
      return build_result(
        pricing_model: variant.pricing_model_override,
        source: "variant_override"
      )
    end

    sub_department = resolved_sub_department
    if sub_department
      return build_result(
        pricing_model: sub_department.default_pricing_model,
        margin_target_bps: sub_department.default_margin_target_bps,
        supplier_discount_bps: sub_department.default_supplier_discount_bps,
        tax_category: sub_department.default_tax_category,
        sales_account_code: department_gl_account(sub_department),
        returnable: sub_department.vendor_returnable_default,
        buyback_allowed: sub_department.buyback_allowed,
        has_list_price: sub_department.has_list_price,
        source: "sub_department"
      )
    end

    @warnings << "No subdepartment assigned; defaults unavailable."
    build_result(source: "none")
  end

  private

  attr_reader :variant, :store, :date, :warnings

  def resolved_sub_department
    variant.sub_department
  end

  def department_gl_account(sub_department)
    sub_department.department&.gl_account_code.presence || sub_department.default_sales_account_code
  end

  def build_result(pricing_model: nil, margin_target_bps: nil, supplier_discount_bps: nil,
                   tax_category: nil, sales_account_code: nil, reporting_bucket: nil,
                   returnable: nil, buyback_allowed: nil, has_list_price: nil, source:)
    @warnings << "No department GL account available." if sales_account_code.blank? && source == "sub_department"

    Result.new(
      pricing_model: pricing_model,
      margin_target_bps: margin_target_bps,
      supplier_discount_bps: supplier_discount_bps,
      tax_category: tax_category,
      sales_account_code: sales_account_code,
      reporting_bucket: reporting_bucket,
      returnable: returnable,
      buyback_allowed: buyback_allowed,
      has_list_price: has_list_price,
      source: source,
      warnings: warnings.dup
    )
  end
end
