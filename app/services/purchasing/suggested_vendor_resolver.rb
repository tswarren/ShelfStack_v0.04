# frozen_string_literal: true

module Purchasing
  class SuggestedVendorResolver
    Result = Data.define(:vendor, :product_variant_vendor, :product_vendor)

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
        .includes(product: :product_vendors)
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

      product_vendors = variant.product.product_vendors.select(&:active?)

      preferred_variant = variant_vendor_rows.find(&:preferred?)
      return result_from_variant_vendor(preferred_variant) if preferred_variant

      preferred_product = product_vendors.find(&:preferred?)
      return result_from_product_vendor(preferred_product) if preferred_product

      first_variant = variant_vendor_rows.first
      return result_from_variant_vendor(first_variant) if first_variant

      first_product = product_vendors.first
      return result_from_product_vendor(first_product) if first_product

      empty_result
    end

    def result_from_variant_vendor(record)
      Result.new(
        vendor: record.vendor,
        product_variant_vendor: record,
        product_vendor: nil
      )
    end

    def result_from_product_vendor(record)
      Result.new(
        vendor: record.vendor,
        product_variant_vendor: nil,
        product_vendor: record
      )
    end

    def empty_result
      Result.new(vendor: nil, product_variant_vendor: nil, product_vendor: nil)
    end
  end
end
