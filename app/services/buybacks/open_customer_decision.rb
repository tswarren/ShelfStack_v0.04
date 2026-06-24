# frozen_string_literal: true

module Buybacks
  class OpenCustomerDecision
    class Error < StandardError; end

    def self.call!(session:, actor:)
      new(session:, actor:).call!
    end

    def initialize(session:, actor:)
      @session = session
      @actor = actor
    end

    def call!
      raise Error, "Proposal must be saved before customer decisions." unless session.quoted?

      session.update!(status: "decision")
      AuditEvents.record!(actor: actor, event_name: "buyback.decision.opened", auditable: session)
      session
    end

    private

    attr_reader :session, :actor
  end
end
