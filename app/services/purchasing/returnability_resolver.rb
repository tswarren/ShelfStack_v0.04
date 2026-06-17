# frozen_string_literal: true

module Purchasing
  class ReturnabilityResolver
    def self.resolve(variant:, vendor: nil)
      new(variant:, vendor:).resolve
    end

    def initialize(variant:, vendor: nil)
      @variant = variant
      @vendor = vendor
    end

    def resolve
      return variant.returnability_status if vendor.blank?

      variant_vendor_status = ProductVariantVendor.active_records
        .find_by(product_variant: variant, vendor: vendor)
        &.returnability_status
      return variant_vendor_status if variant_vendor_status.present?

      product_vendor_status = ProductVendor.active_records
        .find_by(product: variant.product, vendor: vendor)
        &.returnability_status
      return product_vendor_status if product_vendor_status.present?

      variant.returnability_status
    end

    def returnable?
      resolve != "non_returnable"
    end

    private

    attr_reader :variant, :vendor
  end
end
