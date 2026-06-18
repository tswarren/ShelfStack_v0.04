# frozen_string_literal: true

module Purchasing
  class PurchaseOrderSummary
    Result = Data.define(
      :total_units,
      :total_cost_cents,
      :total_retail_cents,
      :net_discount_cents,
      :net_discount_bps
    )

    def self.call(purchase_order)
      new(purchase_order).call
    end

    def initialize(purchase_order)
      @purchase_order = purchase_order
    end

    def call
      total_units = 0
      total_cost_cents = 0
      total_retail_cents = 0

      purchase_order.purchase_order_lines.each do |line|
        qty = line.quantity_ordered
        total_units += qty
        total_cost_cents += (line.unit_cost_cents || 0) * qty
        total_retail_cents += (line.unit_list_price_cents || 0) * qty
      end

      net_discount_cents = total_retail_cents - total_cost_cents
      net_discount_bps = if total_retail_cents.positive?
        ((net_discount_cents.to_f / total_retail_cents) * 10_000).round
      end

      Result.new(
        total_units: total_units,
        total_cost_cents: total_cost_cents,
        total_retail_cents: total_retail_cents,
        net_discount_cents: net_discount_cents,
        net_discount_bps: net_discount_bps
      )
    end

    private

    attr_reader :purchase_order
  end
end
