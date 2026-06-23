# frozen_string_literal: true

module Buybacks
  class ApplyOfferOverride
    class Error < StandardError; end

    def self.call!(line:, actor:, offer_cents:, override_reason:)
      new(line:, actor:, offer_cents:, override_reason:).call!
    end

    def initialize(line:, actor:, offer_cents:, override_reason:)
      @line = line
      @actor = actor
      @offer_cents = offer_cents
      @override_reason = override_reason
    end

    def call!
      raise Error, "Override reason is required." if override_reason.blank?
      raise Error, "Session is not editable." unless line.buyback_session.editable?

      line.update!(
        accepted_offer_cents: offer_cents,
        offer_overridden: true,
        override_reason: override_reason
      )

      AuditEvents.record!(actor: actor, event_name: "buyback.line.offer_overridden", auditable: line)
      line
    end

    private

    attr_reader :line, :actor, :offer_cents, :override_reason
  end
end
