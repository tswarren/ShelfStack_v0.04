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

    def initialize(variant:, vendor:)
      @variant = variant
      @vendor = vendor
    end

    def lookup
      variant_vendor = ProductVariantVendor.active_records.find_by(product_variant: variant, vendor: vendor)
      product_vendor = ProductVendor.active_records.find_by(product: variant.product, vendor: vendor)

      Result.new(
        product_variant_vendor: variant_vendor,
        product_vendor: product_vendor,
        vendor_item_number: variant_vendor&.vendor_item_number || product_vendor&.vendor_item_number,
        supplier_discount_bps: resolved_discount_bps(variant_vendor, product_vendor),
        preferred: variant_vendor&.preferred || product_vendor&.preferred || false,
        sourcing_record_present: variant_vendor.present? || product_vendor.present?
      )
    end

    private

    attr_reader :variant, :vendor

    def resolved_discount_bps(variant_vendor, product_vendor)
      variant_vendor&.supplier_discount_bps ||
        product_vendor&.supplier_discount_bps ||
        vendor.default_supplier_discount_bps
    end
  end
end
