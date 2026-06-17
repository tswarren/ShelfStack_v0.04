# frozen_string_literal: true

module Purchasing
  class VendorCostCalculator
    def self.unit_cost_cents(unit_list_price_cents:, supplier_discount_bps: nil)
      new(unit_list_price_cents:, supplier_discount_bps:).unit_cost_cents
    end

    def initialize(unit_list_price_cents:, supplier_discount_bps: nil)
      @unit_list_price_cents = unit_list_price_cents
      @supplier_discount_bps = supplier_discount_bps
    end

    def unit_cost_cents
      return nil if unit_list_price_cents.nil?

      discount = supplier_discount_bps || 0
      ((unit_list_price_cents * (10_000 - discount)) / 10_000.0).round
    end

    private

    attr_reader :unit_list_price_cents, :supplier_discount_bps
  end
end
