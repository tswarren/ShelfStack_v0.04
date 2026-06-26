# frozen_string_literal: true

module Purchasing
  class SuggestedVendorResolver
    SOURCES = %w[
      variant_preferred
      product_preferred
      variant_vendor_source
      product_vendor_source
      variant_vendor_fallback
      product_vendor_fallback
      none
    ].freeze

    Result = Data.define(:vendor, :product_variant_vendor, :product_vendor, :source)

    def self.for_variant(variant)
      for_variants([ variant.id ]).fetch(variant.id) { empty_result }
    end

    def self.for_variants(variant_ids)
      new(variant_ids:).lookup
    end

    def initialize(variant_ids:)
      @variant_ids = Array(variant_ids).compact.uniq
    end

    def lookup
      return {} if variant_ids.empty?

      variants = ProductVariant
        .where(id: variant_ids)
        .includes(product: :product_vendors, preferred_vendor: {})
        .index_by(&:id)

      variant_vendors = ProductVariantVendor
        .active_records
        .where(product_variant_id: variant_ids)
        .includes(:vendor)
        .group_by(&:product_variant_id)

      variant_ids.index_with do |variant_id|
        resolve_variant(variants[variant_id], variant_vendors[variant_id] || [])
      end
    end

    private

    attr_reader :variant_ids

    def resolve_variant(variant, variant_vendor_rows)
      return empty_result if variant.blank?

      if variant.preferred_vendor&.active?
        return result_from_preferred_vendor(variant.preferred_vendor, :variant_preferred)
      end

      product = variant.product
      if product.preferred_vendor&.active?
        return result_from_preferred_vendor(product.preferred_vendor, :product_preferred)
      end

      product_vendors = product.product_vendors.select(&:active?)

      preferred_variant = variant_vendor_rows.find(&:preferred?)
      return result_from_variant_vendor(preferred_variant, :variant_vendor_source) if preferred_variant

      preferred_product = product_vendors.find(&:preferred?)
      return result_from_product_vendor(preferred_product, :product_vendor_source) if preferred_product

      first_variant = variant_vendor_rows.first
      return result_from_variant_vendor(first_variant, :variant_vendor_fallback) if first_variant

      first_product = product_vendors.first
      return result_from_product_vendor(first_product, :product_vendor_fallback) if first_product

      empty_result
    end

    def result_from_preferred_vendor(vendor, source)
      Result.new(vendor: vendor, product_variant_vendor: nil, product_vendor: nil, source: source.to_s)
    end

    def result_from_variant_vendor(record, source)
      Result.new(
        vendor: record.vendor,
        product_variant_vendor: record,
        product_vendor: nil,
        source: source.to_s
      )
    end

    def result_from_product_vendor(record, source)
      Result.new(
        vendor: record.vendor,
        product_variant_vendor: nil,
        product_vendor: record,
        source: source.to_s
      )
    end

    def empty_result
      Result.new(vendor: nil, product_variant_vendor: nil, product_vendor: nil, source: "none")
    end
  end
end
