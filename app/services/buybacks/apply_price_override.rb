# frozen_string_literal: true

module Buybacks
  class ApplyPriceOverride
    class Error < StandardError; end

    def self.call!(line:, actor:, resale_price_cents:, override_reason:)
      new(line:, actor:, resale_price_cents:, override_reason:).call!
    end

    def initialize(line:, actor:, resale_price_cents:, override_reason:)
      @line = line
      @actor = actor
      @resale_price_cents = resale_price_cents
      @override_reason = override_reason
    end

    def call!
      raise Error, "Override reason is required." if override_reason.blank?
      raise Error, "Session is not editable." unless line.buyback_session.editable?

      line.base_price_cents = resale_price_cents
      line.base_price_source = "manual_resale_price"
      line.proposed_resale_price_cents = resale_price_cents

      pricing = PriceLine.call(line: line, resale_override_cents: resale_price_cents)
      line.assign_attributes(
        suggested_resale_price_cents: pricing.resale_price_cents,
        suggested_cash_offer_cents: pricing.cash_offer_cents,
        suggested_trade_credit_offer_cents: pricing.trade_credit_offer_cents,
        buyback_pricing_rule: pricing.pricing_rule,
        resale_price_overridden: true,
        resale_price_override_reason: override_reason,
        status: "priced"
      )
      line.proposed_cash_offer_cents = pricing.cash_offer_cents unless line.cash_offer_overridden?
      line.proposed_trade_credit_offer_cents = pricing.trade_credit_offer_cents unless line.trade_credit_offer_overridden?
      clear_stale_decision!(line)
      line.save!

      AuditEvents.record!(actor: actor, event_name: "buyback.line.price_overridden", auditable: line)
      line
    end

    private

    attr_reader :line, :actor, :resale_price_cents, :override_reason

    def clear_stale_decision!(line)
      return unless line.outcome.present? || line.status == "decided"

      line.outcome = nil
      line.customer_decision_at = nil
    end
  end
end
