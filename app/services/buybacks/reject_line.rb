# frozen_string_literal: true

module Buybacks
  class RejectLine
    class Error < StandardError; end

    REJECT_OUTCOMES = %w[declined_by_customer rejected_by_store recycle_with_permission].freeze

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
      raise Error, "Invalid rejection outcome." unless outcome.in?(REJECT_OUTCOMES)
      raise Error, "Session is not editable." unless line.buyback_session.editable?
      raise Error, "Posted or voided lines cannot be changed." if line.status.in?(%w[posted voided])
      if outcome == "rejected_by_store" && reject_reason.blank?
        raise Error, "Reject reason is required for store-rejected lines."
      end

      line.update!(
        status: "decided",
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
