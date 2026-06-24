# frozen_string_literal: true

module Buybacks
  class CancelSession
    def self.call!(session:, actor:)
      new(session:, actor:).call!
    end

    def initialize(session:, actor:)
      @session = session
      @actor = actor
    end

    def call!
      raise ArgumentError, "Session cannot be cancelled." unless session.editable?

      session.update!(status: "cancelled", cancelled_at: Time.current, cancelled_by_user: actor)
      AuditEvents.record!(actor: actor, event_name: "buyback.session.cancelled", auditable: session)
      session
    end

    private

    attr_reader :session, :actor
  end
end
