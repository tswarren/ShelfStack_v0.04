# frozen_string_literal: true

module Buybacks
  # 7C-1 uses fixed base-price precedence on the line (see #base_price_cents).
  # BuybackPricingRule#base_price_source is reserved for future rule-driven bases.
  class PriceLine
    Result = Data.define(
      :resale_price_cents,
      :cash_offer_cents,
      :trade_credit_offer_cents,
      :pricing_rule
    )

    def self.call(line:, resale_override_cents: nil)
      new(line:, resale_override_cents:).call
    end

    def initialize(line:, resale_override_cents: nil)
      @line = line
      @resale_override_cents = resale_override_cents
    end

    def call
      rule = matching_rule
      resale = if resale_override_cents.present?
        resale_override_cents.to_i
      else
        apply_factor(base_price_cents(rule), rule&.resale_price_factor_bps || condition_factor_bps)
      end
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

    attr_reader :line, :resale_override_cents

    def matching_rule
      scope = BuybackPricingRule.active_records.order(:sort_order)
      specific = scope.find_by(sub_department_id: line.sub_department_id, product_condition_id: line.product_condition_id)
      return specific if specific.present?

      scope.find_by(sub_department_id: line.sub_department_id, product_condition_id: nil) ||
        scope.find_by(sub_department_id: nil, product_condition_id: line.product_condition_id) ||
        scope.find_by(sub_department_id: nil, product_condition_id: nil)
    end

    def base_price_cents(_rule)
      return line.base_price_cents if line.base_price_cents.to_i.positive?

      list = line.product&.list_price_cents || line.list_price_cents
      return list if list.to_i.positive?

      if line.product_variant_id.present?
        variant_price = line.product_variant&.selling_price_cents || line.current_selling_price_cents
        return variant_price if variant_price.to_i.positive?
      end

      line.proposed_resale_price_cents || line.suggested_resale_price_cents || 0
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
      amount = [ rounded, min ].max
      max.present? ? [ amount, max ].min : amount
    end
  end
end
