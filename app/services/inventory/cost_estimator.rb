# frozen_string_literal: true

module Inventory
  class CostEstimator
    Result = Data.define(:unit_cost_cents, :total_cost_cents, :unit_retail_cents, :total_retail_cents, :cost_source, :retail_source)

    def self.estimate(variant:, quantity_delta:, manual_unit_cost_cents: nil, cost_source: nil)
      new(variant:, quantity_delta:, manual_unit_cost_cents:, cost_source:).estimate
    end

    def initialize(variant:, quantity_delta:, manual_unit_cost_cents: nil, cost_source: nil)
      @variant = variant
      @quantity_delta = quantity_delta
      @manual_unit_cost_cents = manual_unit_cost_cents
      @cost_source = cost_source
    end

    def estimate
      retail = retail_snapshot
      cost = cost_snapshot

      Result.new(
        unit_cost_cents: cost[:unit_cost_cents],
        total_cost_cents: cost[:total_cost_cents],
        unit_retail_cents: retail[:unit_retail_cents],
        total_retail_cents: retail[:total_retail_cents],
        cost_source: cost[:cost_source],
        retail_source: retail[:retail_source]
      )
    end

    private

    attr_reader :variant, :quantity_delta, :manual_unit_cost_cents, :cost_source

    def retail_snapshot
      unit = variant.selling_price_cents
      if unit.nil?
        return {
          unit_retail_cents: nil,
          total_retail_cents: nil,
          retail_source: "unknown"
        }
      end

      {
        unit_retail_cents: unit,
        total_retail_cents: unit * quantity_delta.abs,
        retail_source: "variant_selling_price"
      }
    end

    def cost_snapshot
      if manual_unit_cost_cents.present?
        return {
          unit_cost_cents: manual_unit_cost_cents,
          total_cost_cents: manual_unit_cost_cents * quantity_delta.abs,
          cost_source: cost_source.presence || "manual"
        }
      end

      margin_bps = variant.sub_department&.default_margin_target_bps
      if margin_bps.present? && variant.selling_price_cents.present?
        unit = ((variant.selling_price_cents * (10_000 - margin_bps)) / 10_000.0).round
        return {
          unit_cost_cents: unit,
          total_cost_cents: unit * quantity_delta.abs,
          cost_source: "margin_estimate"
        }
      end

      {
        unit_cost_cents: nil,
        total_cost_cents: nil,
        cost_source: "unknown"
      }
    end
  end
end
