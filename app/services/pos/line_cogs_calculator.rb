# frozen_string_literal: true

module Pos
  class LineCogsCalculator
    Result = Data.define(
      :unit_cogs_cents,
      :total_cogs_cents,
      :cogs_source,
      :costing_method_snapshot,
      :revenue_treatment,
      :cogs_estimated
    )

    COGS_SOURCES = %w[
      moving_average unit_cost receipt_cost buyback_offer margin_estimate
      return_reversal none unknown
    ].freeze

    REVENUE_TREATMENTS = %w[merchandise service liability passthrough none].freeze

    def self.call(line:, store:)
      new(line:, store:).call
    end

    def initialize(line:, store:)
      @line = line
      @store = store
    end

    def call
      if line.gift_card_sale_line?
        return no_cogs(revenue_treatment: "liability")
      end

      if line.open_ring_line?
        return open_ring_cogs
      end

      return no_cogs(revenue_treatment: "none") unless line.variant_line?

      variant = line.product_variant
      return no_cogs(revenue_treatment: "none") if variant.blank?

      if line.return_line? && line.source_transaction_line&.unit_cogs_cents.present?
        return sourced_return_cogs(line.source_transaction_line)
      end

      unless Inventory::Eligibility.eligible?(variant)
        return no_cogs(revenue_treatment: non_inventory_revenue_treatment(variant))
      end

      return blind_return_cogs if line.return_line?

      inventory_sale_cogs
    end

    private

    attr_reader :line, :store

    def inventory_sale_cogs
      balance = InventoryBalance.find_by(store: store, product_variant: line.product_variant)
      unit = balance&.moving_average_unit_cost_cents.presence ||
        balance&.unit_cost_cents.presence ||
        margin_estimate_unit_cost

      if unit.nil?
        return Result.new(
          unit_cogs_cents: nil,
          total_cogs_cents: nil,
          cogs_source: "unknown",
          costing_method_snapshot: "unknown",
          revenue_treatment: "merchandise",
          cogs_estimated: true
        )
      end

      source = balance_source(balance, unit)
      estimated = source == "margin_estimate"

      Result.new(
        unit_cogs_cents: unit,
        total_cogs_cents: unit * line.quantity,
        cogs_source: source,
        costing_method_snapshot: estimated ? "margin_estimate" : "moving_average",
        revenue_treatment: "merchandise",
        cogs_estimated: estimated
      )
    end

    def sourced_return_cogs(source_line)
      unit = source_line.unit_cogs_cents
      Result.new(
        unit_cogs_cents: unit,
        total_cogs_cents: unit * line.quantity,
        cogs_source: "return_reversal",
        costing_method_snapshot: source_line.costing_method_snapshot || "return_reversal",
        revenue_treatment: "merchandise",
        cogs_estimated: source_line.cogs_estimated?
      )
    end

    def blind_return_cogs
      fallback = inventory_sale_cogs
      Result.new(
        unit_cogs_cents: fallback.unit_cogs_cents,
        total_cogs_cents: fallback.unit_cogs_cents ? fallback.unit_cogs_cents * line.quantity : nil,
        cogs_source: fallback.cogs_source,
        costing_method_snapshot: fallback.costing_method_snapshot,
        revenue_treatment: "merchandise",
        cogs_estimated: true
      )
    end

    def non_inventory_revenue_treatment(variant)
      case variant.product.product_type
      when "financial"
        "liability"
      when "service"
        "service"
      else
        "none"
      end
    end

    def open_ring_cogs
      unit = margin_estimate_for_subdepartment(line.sub_department)
      if unit.nil?
        return no_cogs(revenue_treatment: "service")
      end

      Result.new(
        unit_cogs_cents: unit,
        total_cogs_cents: unit * line.quantity,
        cogs_source: "margin_estimate",
        costing_method_snapshot: "margin_estimate",
        revenue_treatment: "service",
        cogs_estimated: true
      )
    end

    def no_cogs(revenue_treatment:)
      Result.new(
        unit_cogs_cents: nil,
        total_cogs_cents: nil,
        cogs_source: "none",
        costing_method_snapshot: "none",
        revenue_treatment: revenue_treatment,
        cogs_estimated: false
      )
    end

    def balance_source(balance, unit)
      if balance&.moving_average_unit_cost_cents == unit
        "moving_average"
      elsif balance&.unit_cost_cents == unit
        "unit_cost"
      else
        "margin_estimate"
      end
    end

    def margin_estimate_unit_cost
      margin_estimate_for_subdepartment(line.product_variant&.sub_department)
    end

    def margin_estimate_for_subdepartment(sub_department)
      return if sub_department.blank?

      margin_bps = sub_department.default_margin_target_bps
      price = line.unit_price_cents
      return if margin_bps.blank? || price.blank?

      ((price * (10_000 - margin_bps)) / 10_000.0).round
    end
  end
end
