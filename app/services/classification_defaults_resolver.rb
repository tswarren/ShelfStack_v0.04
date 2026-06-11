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

    mapping = AccountingMappingLookup.match_for(variant: variant)
    if mapping
      mc = mapping.merchandise_class || merchandise_class
      return build_result(
        pricing_model: mc&.default_pricing_model || category&.default_pricing_model,
        margin_target_bps: mc&.default_margin_target_bps || category&.default_margin_target_bps,
        supplier_discount_bps: mc&.default_supplier_discount_bps || category&.default_supplier_discount_bps,
        tax_category: mc&.default_tax_category || category&.default_tax_category,
        sales_account_code: mapping.sales_account_code,
        reporting_bucket: mapping.reporting_bucket,
        returnable: mc&.vendor_returnable_default,
        buyback_allowed: mc&.buyback_allowed,
        has_list_price: mc&.has_list_price,
        source: "accounting_mapping"
      )
    end

    if merchandise_class
      return build_result(
        pricing_model: merchandise_class.default_pricing_model,
        margin_target_bps: merchandise_class.default_margin_target_bps,
        supplier_discount_bps: merchandise_class.default_supplier_discount_bps,
        tax_category: merchandise_class.default_tax_category,
        sales_account_code: merchandise_class.default_sales_account_code,
        returnable: merchandise_class.vendor_returnable_default,
        buyback_allowed: merchandise_class.buyback_allowed,
        has_list_price: merchandise_class.has_list_price,
        source: "merchandise_class"
      )
    end

    if category
      @warnings << "Merchandise class missing; using legacy category defaults." if category.merchandise_class.blank?
      return build_result(
        pricing_model: category.default_pricing_model,
        margin_target_bps: category.default_margin_target_bps,
        supplier_discount_bps: category.default_supplier_discount_bps,
        tax_category: category.default_tax_category,
        sales_account_code: category.department&.gl_account_code,
        source: "legacy_category"
      )
    end

    if category&.department&.gl_account_code.present?
      @warnings << "No category assigned; using department GL account fallback."
      return build_result(
        sales_account_code: category.department.gl_account_code,
        source: "legacy_department"
      )
    end

    @warnings << "No category assigned; defaults unavailable."
    build_result(source: "none")
  end

  private

  attr_reader :variant, :store, :date, :warnings

  def category
    variant.category
  end

  def merchandise_class
    category&.merchandise_class
  end

  def build_result(pricing_model: nil, margin_target_bps: nil, supplier_discount_bps: nil,
                   tax_category: nil, sales_account_code: nil, reporting_bucket: nil,
                   returnable: nil, buyback_allowed: nil, has_list_price: nil, source:)
    if sales_account_code.blank? && source.in?(%w[merchandise_class legacy_category])
      sales_account_code = category&.department&.gl_account_code
    end
    @warnings << "Using department GL account as reporting fallback." if source == "legacy_category" && sales_account_code == category&.department&.gl_account_code
    @warnings << "No sales account mapping matched." if sales_account_code.blank? && source != "variant_override"

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
