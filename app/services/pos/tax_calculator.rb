# frozen_string_literal: true

module Pos
  class TaxCalculator
    LineTax = Data.define(:tax_category, :store_tax_rate, :tax_rate_bps, :tax_cents)

    def self.snapshot_for_subdepartment!(sub_department:, store:, business_date:, taxable_cents:)
      new(variant: nil, sub_department:, store:, business_date:, taxable_cents:).snapshot_for_subdepartment!
    end

    def self.snapshot_for_variant!(variant:, store:, business_date:, taxable_cents:)
      new(variant:, store:, business_date:, taxable_cents:).snapshot_for_variant!
    end

    def initialize(variant:, store:, business_date:, taxable_cents:, sub_department: nil)
      @variant = variant
      @sub_department = sub_department
      @store = store
      @business_date = business_date.to_date
      @taxable_cents = taxable_cents
    end

    def snapshot_for_subdepartment!
      tax_category = sub_department&.default_tax_category
      raise MissingTaxError, "Subdepartment has no default tax category." if tax_category.blank?

      build_line_tax(tax_category:)
    end

    def snapshot_for_variant!
      defaults = ClassificationDefaultsResolver.for(variant:, store:, date: business_date)
      raise MissingTaxError, defaults.warnings.join(" ") if defaults.tax_category.blank?

      build_line_tax(tax_category: defaults.tax_category)
    end

    MissingTaxError = Class.new(StandardError)

    private

    attr_reader :variant, :sub_department, :store, :business_date, :taxable_cents

    def build_line_tax(tax_category:)
      rate = TaxRateLookup.call(store:, tax_category:, date: business_date)
      tax_cents = ((taxable_cents * rate.tax_rate_bps) / 10_000.0).round

      LineTax.new(
        tax_category: tax_category,
        store_tax_rate: rate,
        tax_rate_bps: rate.tax_rate_bps,
        tax_cents: tax_cents
      )
    end
  end
end
