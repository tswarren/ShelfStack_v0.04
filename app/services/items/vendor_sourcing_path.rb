# frozen_string_literal: true

module Items
  class VendorSourcingPath
    include Rails.application.routes.url_helpers

    def self.for(variant)
      new(variant).call
    end

    def initialize(variant)
      @variant = variant
      @product = variant.product
    end

    def call
      vendor = Purchasing::SuggestedVendorResolver.for_variant(variant).vendor
      if vendor.present?
        sourcing = Purchasing::SourcingLookup.for(variant: variant, vendor: vendor)
        return edit_items_product_variant_product_variant_vendor_path(variant, sourcing.product_variant_vendor) if sourcing.product_variant_vendor.present?
        return edit_items_product_product_vendor_path(product, sourcing.product_vendor) if sourcing.product_vendor.present?
        return new_items_product_variant_product_variant_vendor_path(variant, vendor_id: vendor.id)
      end

      if ProductVendor.active_records.where(product: product).none?
        new_items_product_product_vendor_path(product)
      else
        new_items_product_variant_product_variant_vendor_path(variant)
      end
    end

    private

    attr_reader :variant, :product
  end
end
