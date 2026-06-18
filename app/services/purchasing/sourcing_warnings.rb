# frozen_string_literal: true

module Purchasing
  class SourcingWarnings
    def self.for_purchase_order(purchase_order)
      new(purchase_order:).warnings
    end

    def initialize(purchase_order:)
      @purchase_order = purchase_order
    end

    def warnings
      return [] if purchase_order.vendor.blank?

      purchase_order.purchase_order_lines.filter_map do |line|
        next if line.marked_for_destruction?
        next if line.product_variant.blank?

        sourcing = SourcingLookup.for(variant: line.product_variant, vendor: purchase_order.vendor)
        next if sourcing.sourcing_record_present

        "No vendor sourcing record for SKU #{line.product_variant.sku} with #{purchase_order.vendor.name}."
      end
    end

    private

    attr_reader :purchase_order
  end
end
