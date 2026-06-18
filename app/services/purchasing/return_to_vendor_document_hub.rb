# frozen_string_literal: true

module Purchasing
  class ReturnToVendorDocumentHub
    Totals = Data.define(:units, :total_credit_cents, :total_cost_cents)

    Result = Data.define(:totals, :inventory_posting)

    def self.call(return_to_vendor)
      new(return_to_vendor).call
    end

    def initialize(return_to_vendor)
      @return_to_vendor = return_to_vendor
    end

    def call
      Result.new(
        totals: totals,
        inventory_posting: return_to_vendor.inventory_posting
      )
    end

    private

    attr_reader :return_to_vendor

    def totals
      lines = return_to_vendor.return_to_vendor_lines.to_a
      Totals.new(
        units: lines.sum(&:quantity),
        total_credit_cents: lines.sum { |line| line.credit_amount_cents || 0 },
        total_cost_cents: lines.sum { |line| (line.unit_cost_cents || 0) * line.quantity }
      )
    end
  end
end
