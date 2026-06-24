# frozen_string_literal: true

module Buybacks
  class RecordCustomerDecision
    class Error < StandardError; end

    def self.call!(line:, session:, actor:, outcome:)
      new(line:, session:, actor:, outcome:).call!
    end

    def initialize(line:, session:, actor:, outcome:)
      @line = line
      @session = session
      @actor = actor
      @outcome = outcome
    end

    def call!
      raise Error, "Session must be in customer decision stage." unless session.decision? || session.quoted?
      raise Error, "Invalid outcome." unless outcome.in?(BuybackLine::OUTCOMES)
      raise Error, "Line must be offered before recording a decision." unless line.status.in?(%w[offered decided])

      timestamp = Time.current
      line.update!(
        outcome: outcome,
        status: "decided",
        customer_decision_at: timestamp
      )

      session.update!(status: "decision", customer_decision_at: timestamp) unless session.decision?

      AuditEvents.record!(
        actor: actor,
        event_name: "buyback.line.decision_recorded",
        auditable: line,
        source: session,
        details: { "outcome" => outcome }
      )

      line
    end

    private

    attr_reader :line, :session, :actor, :outcome
  end
end
