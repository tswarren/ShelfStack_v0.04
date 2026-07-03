# frozen_string_literal: true

module Purchasing
  class SourcingLookup
    Result = Data.define(
      :product_variant_vendor,
      :product_vendor,
      :vendor_item_number,
      :supplier_discount_bps,
      :preferred,
      :sourcing_record_present
    )

    def self.for(variant:, vendor:)
      new(variant:, vendor:).lookup
    end

    def self.for_variants(variants:, vendors_by_variant_id:)
      variants = Array(variants).compact
      return {} if variants.empty?

      variant_ids = variants.map(&:id)
      product_ids = variants.map(&:product_id).uniq
      vendor_ids = vendors_by_variant_id.values.compact.map(&:id).uniq

      variant_vendors_by_key = ProductVariantVendor.active_records
        .where(product_variant_id: variant_ids, vendor_id: vendor_ids)
        .index_by { |record| [ record.product_variant_id, record.vendor_id ] }

      product_vendors_by_key = ProductVendor.active_records
        .where(product_id: product_ids, vendor_id: vendor_ids)
        .index_by { |record| [ record.product_id, record.vendor_id ] }

      variants.each_with_object({}) do |variant, results|
        vendor = vendors_by_variant_id[variant.id]
        next results[variant.id] = nil if vendor.blank?

        variant_vendor = variant_vendors_by_key[[ variant.id, vendor.id ]]
        product_vendor = product_vendors_by_key[[ variant.product_id, vendor.id ]]
        results[variant.id] = build_result(variant:, variant_vendor:, product_vendor:, vendor:)
      end
    end

    def initialize(variant:, vendor:)
      @variant = variant
      @vendor = vendor
    end

    def lookup
      variant_vendor = ProductVariantVendor.active_records.find_by(product_variant: variant, vendor: vendor)
      product_vendor = ProductVendor.active_records.find_by(product: variant.product, vendor: vendor)

      self.class.build_result(variant:, variant_vendor:, product_vendor:, vendor:)
    end

    def self.build_result(variant:, variant_vendor:, product_vendor:, vendor:)
      Result.new(
        product_variant_vendor: variant_vendor,
        product_vendor: product_vendor,
        vendor_item_number: resolve_vendor_item_number(
          variant: variant,
          variant_vendor: variant_vendor,
          product_vendor: product_vendor
        ),
        supplier_discount_bps: resolved_discount_bps(variant_vendor, product_vendor, vendor),
        preferred: variant_vendor&.preferred || product_vendor&.preferred || false,
        sourcing_record_present: variant_vendor.present? || product_vendor.present?
      )
    end

    def self.resolve_vendor_item_number(variant:, variant_vendor: nil, product_vendor: nil)
      variant_vendor&.vendor_item_number.presence ||
        product_vendor&.vendor_item_number.presence ||
        primary_identifier_value(variant.product)
    end

    def self.primary_identifier_value(product)
      product.primary_identifier&.normalized_identifier.presence
    end

    def self.resolved_discount_bps(variant_vendor, product_vendor, vendor)
      variant_vendor&.supplier_discount_bps ||
        product_vendor&.supplier_discount_bps ||
        vendor.default_supplier_discount_bps
    end

    private

    attr_reader :variant, :vendor
  end
end
