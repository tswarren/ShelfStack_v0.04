# frozen_string_literal: true

module Buybacks
  class ApplyOfferOverride
    class Error < StandardError; end

    OFFER_TYPES = %w[cash trade_credit].freeze

    def self.call!(line:, actor:, offer_cents:, override_reason:, offer_type: "cash")
      new(line:, actor:, offer_cents:, override_reason:, offer_type:).call!
    end

    def initialize(line:, actor:, offer_cents:, override_reason:, offer_type: "cash")
      @line = line
      @actor = actor
      @offer_cents = offer_cents
      @override_reason = override_reason
      @offer_type = offer_type
    end

    def call!
      raise Error, "Override reason is required." if override_reason.blank?
      raise Error, "Session is not editable." unless line.buyback_session.editable?
      raise Error, "Invalid offer type." unless offer_type.in?(OFFER_TYPES)

      updates = { status: "priced" }
      if offer_type == "trade_credit"
        updates[:proposed_trade_credit_offer_cents] = offer_cents
        updates[:trade_credit_offer_overridden] = true
        updates[:trade_credit_offer_override_reason] = override_reason
      else
        updates[:proposed_cash_offer_cents] = offer_cents
        updates[:cash_offer_overridden] = true
        updates[:cash_offer_override_reason] = override_reason
      end

      line.update!(updates)
      AuditEvents.record!(actor: actor, event_name: "buyback.line.offer_overridden", auditable: line,
                          details: { "offer_type" => offer_type })
      line
    end

    private

    attr_reader :line, :actor, :offer_cents, :override_reason, :offer_type
  end
end
