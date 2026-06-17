# frozen_string_literal: true

module Purchasing
  class LinePriceDefaults
    Result = Data.define(
      :unit_list_price_cents,
      :supplier_discount_bps,
      :unit_cost_cents,
      :product_variant_vendor
    )

    def self.apply!(line)
      new(line).apply!
    end

    def self.resolve(variant:, vendor:, purchase_order_line: nil)
      new(variant:, vendor:, purchase_order_line:).resolve
    end

    def initialize(line = nil, variant: nil, vendor: nil, purchase_order_line: nil)
      @line = line
      @variant = variant || line&.product_variant
      @vendor = vendor || line_vendor(line)
      @purchase_order_line = purchase_order_line || line&.try(:purchase_order_line)
    end

    def apply!
      return line if line.blank? || variant.blank?

      defaults = resolve
      line.unit_list_price_cents = defaults.unit_list_price_cents if line.unit_list_price_cents.nil?
      line.supplier_discount_bps = defaults.supplier_discount_bps if line.supplier_discount_bps.nil?
      line.unit_cost_cents = defaults.unit_cost_cents if line.unit_cost_cents.nil?
      if line.respond_to?(:product_variant_vendor=) && line.product_variant_vendor.nil?
        line.product_variant_vendor = defaults.product_variant_vendor
      end
      line
    end

    def resolve
      return from_purchase_order_line if purchase_order_line.present?

      sourcing = vendor.present? ? SourcingLookup.for(variant: variant, vendor: vendor) : nil
      list_price = variant_list_price_cents
      discount_bps = sourcing&.supplier_discount_bps

      Result.new(
        unit_list_price_cents: list_price,
        supplier_discount_bps: discount_bps,
        unit_cost_cents: VendorCostCalculator.unit_cost_cents(
          unit_list_price_cents: list_price,
          supplier_discount_bps: discount_bps
        ),
        product_variant_vendor: sourcing&.product_variant_vendor
      )
    end

    private

    attr_reader :line, :variant, :vendor, :purchase_order_line

    def from_purchase_order_line
      Result.new(
        unit_list_price_cents: purchase_order_line.unit_list_price_cents,
        supplier_discount_bps: purchase_order_line.supplier_discount_bps,
        unit_cost_cents: purchase_order_line.unit_cost_cents,
        product_variant_vendor: purchase_order_line.product_variant_vendor
      )
    end

    def variant_list_price_cents
      product_list = variant.product&.list_price_cents
      return product_list if product_list.present? && product_list.positive?

      variant.selling_price_cents
    end

    def line_vendor(line)
      return nil if line.blank?

      if line.respond_to?(:vendor) && line.vendor.present?
        line.vendor
      elsif line.respond_to?(:purchase_order) && line.purchase_order&.vendor.present?
        line.purchase_order.vendor
      elsif line.respond_to?(:receipt) && line.receipt&.vendor.present?
        line.receipt.vendor
      end
    end
  end
end
