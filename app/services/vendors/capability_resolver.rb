# frozen_string_literal: true

module Vendors
  class CapabilityResolver
    Result = Data.define(
      :availability_workflow,
      :availability_source,
      :order_submission_method,
      :acknowledgment_method,
      :shipment_notice_method,
      :invoice_method,
      :technical_acknowledgment_method,
      :fulfillment_methods_supported,
      :capability_source
    )

    def self.call(vendor:, product: nil, product_variant: nil, product_vendor: nil, product_variant_vendor: nil)
      new(
        vendor:,
        product:,
        product_variant:,
        product_vendor:,
        product_variant_vendor:
      ).call
    end

    def initialize(vendor:, product: nil, product_variant: nil, product_vendor: nil, product_variant_vendor: nil)
      @vendor = vendor
      @product = product
      @product_variant = product_variant
      @product_vendor = product_vendor
      @product_variant_vendor = product_variant_vendor
    end

    def call
      Result.new(
        availability_workflow: vendor.availability_workflow,
        availability_source: vendor.availability_source,
        order_submission_method: vendor.order_submission_method,
        acknowledgment_method: vendor.acknowledgment_method,
        shipment_notice_method: vendor.shipment_notice_method,
        invoice_method: vendor.invoice_method,
        technical_acknowledgment_method: vendor.technical_acknowledgment_method,
        fulfillment_methods_supported: Array(vendor.fulfillment_methods_supported),
        capability_source: resolve_capability_source
      )
    end

    private

    attr_reader :vendor, :product, :product_variant, :product_vendor, :product_variant_vendor

    def resolve_capability_source
      return "product_variant_vendor" if product_variant_vendor.present?
      return "product_vendor" if product_vendor.present?

      "vendor"
    end
  end
end
