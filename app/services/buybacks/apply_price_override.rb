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

      pricing = PriceLine.call(line: line)
      line.update!(
        accepted_resale_price_cents: resale_price_cents,
        suggested_resale_price_cents: pricing.resale_price_cents,
        suggested_cash_offer_cents: pricing.cash_offer_cents,
        suggested_trade_credit_offer_cents: pricing.trade_credit_offer_cents,
        resale_price_overridden: true,
        override_reason: override_reason,
        status: "priced"
      )

      AuditEvents.record!(actor: actor, event_name: "buyback.line.price_overridden", auditable: line)
      line
    end

    private

    attr_reader :line, :actor, :resale_price_cents, :override_reason
  end
end
