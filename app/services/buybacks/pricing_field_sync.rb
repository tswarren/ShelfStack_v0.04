# frozen_string_literal: true

module Buybacks
  module PricingFieldSync
    module_function

    def apply_suggested_values!(line, pricing)
      line.suggested_resale_price_cents = pricing.resale_price_cents
      line.suggested_cash_offer_cents = pricing.cash_offer_cents
      line.suggested_trade_credit_offer_cents = pricing.trade_credit_offer_cents
      line.buyback_pricing_rule = pricing.pricing_rule

      line.proposed_resale_price_cents = pricing.resale_price_cents unless line.resale_price_overridden?
      line.proposed_cash_offer_cents = pricing.cash_offer_cents unless line.cash_offer_overridden?
      line.proposed_trade_credit_offer_cents = pricing.trade_credit_offer_cents unless line.trade_credit_offer_overridden?
    end

    def refresh!(line:)
      return nil if line.product_condition.blank? || line.sub_department.blank?

      pricing = PriceLine.call(line: line)
      apply_suggested_values!(line, pricing)
      if line.proposed_resale_price_cents.to_i.positive? && line.status.in?(%w[pending resolved])
        line.status = "priced"
      end
      line.save!
      pricing
    end
  end
end
