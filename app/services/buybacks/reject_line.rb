# frozen_string_literal: true

module Buybacks
  class RejectLine
    class Error < StandardError; end

    def self.call!(line:, actor:, outcome:, reject_reason: nil)
      new(line:, actor:, outcome:, reject_reason:).call!
    end

    def initialize(line:, actor:, outcome:, reject_reason: nil)
      @line = line
      @actor = actor
      @outcome = outcome
      @reject_reason = reject_reason
    end

    def call!
      raise Error, "Invalid outcome." unless outcome.in?(BuybackLine::OUTCOMES)

      status = outcome == "rejected_by_store" ? line.status : "decided"
      line.update!(
        status: status,
        outcome: outcome,
        buyback_reject_reason: reject_reason,
        customer_decision_at: Time.current
      )

      AuditEvents.record!(
        actor: actor,
        event_name: "buyback.line.rejected",
        auditable: line,
        source: line.buyback_session,
        details: { "outcome" => outcome }
      )
      line
    end

    private

    attr_reader :line, :actor, :outcome, :reject_reason
  end
end
