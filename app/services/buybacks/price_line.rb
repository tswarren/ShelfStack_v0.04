# frozen_string_literal: true

module Buybacks
  class PriceLine
    Result = Data.define(
      :resale_price_cents,
      :cash_offer_cents,
      :trade_credit_offer_cents,
      :pricing_rule
    )

    def self.call(line:)
      new(line:).call
    end

    def initialize(line:)
      @line = line
    end

    def call
      rule = matching_rule
      base = base_price_cents(rule)
      resale = apply_factor(base, rule&.resale_price_factor_bps || condition_factor_bps)
      cash = apply_offer(resale, rule&.cash_offer_bps || 2500, rule)
      credit = apply_offer(resale, rule&.trade_credit_offer_bps || 3000, rule)

      Result.new(
        resale_price_cents: resale,
        cash_offer_cents: cash,
        trade_credit_offer_cents: credit,
        pricing_rule: rule
      )
    end

    private

    attr_reader :line

    def matching_rule
      scope = BuybackPricingRule.active_records.order(:sort_order)
      specific = scope.find_by(sub_department_id: line.sub_department_id, product_condition_id: line.product_condition_id)
      return specific if specific.present?

      scope.find_by(sub_department_id: line.sub_department_id, product_condition_id: nil) ||
        scope.find_by(sub_department_id: nil, product_condition_id: line.product_condition_id) ||
        scope.find_by(sub_department_id: nil, product_condition_id: nil)
    end

    def base_price_cents(rule)
      source = rule&.base_price_source || "variant_selling_price"
      case source
      when "product_list_price"
        line.product&.list_price_cents || line.list_price_cents || 0
      when "variant_selling_price"
        line.product_variant&.selling_price_cents || line.current_selling_price_cents || 0
      when "condition_adjusted_list_price"
        list = line.product&.list_price_cents || line.list_price_cents || 0
        apply_factor(list, condition_factor_bps)
      else
        line.accepted_resale_price_cents || line.suggested_resale_price_cents || 0
      end
    end

    def condition_factor_bps
      line.product_condition&.buyback_price_factor_bps ||
        line.product_condition&.default_list_price_factor_bps ||
        10_000
    end

    def apply_factor(amount, factor_bps)
      ((amount.to_i * factor_bps) / 10_000.0).round
    end

    def apply_offer(resale, offer_bps, rule)
      raw = ((resale.to_i * offer_bps) / 10_000.0).round
      increment = rule&.rounding_increment_cents || 100
      rounded = (raw.to_f / increment).round * increment
      min = rule&.minimum_offer_cents || 0
      max = rule&.maximum_offer_cents
      amount = [rounded, min].max
      max.present? ? [amount, max].min : amount
    end
  end
end
