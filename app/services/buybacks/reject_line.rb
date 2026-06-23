# frozen_string_literal: true

module Buybacks
  class RejectLine
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
      line.update!(
        status: "rejected",
        outcome: outcome,
        buyback_reject_reason: reject_reason
      )

      AuditEvents.record!(
        actor: actor,
        event_name: "buyback.line.rejected",
        auditable: line,
        source: line.buyback_session
      )
      line
    end

    private

    attr_reader :line, :actor, :outcome, :reject_reason
  end
end
