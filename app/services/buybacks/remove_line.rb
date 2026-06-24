# frozen_string_literal: true

module Buybacks
  class RemoveLine
    class Error < StandardError; end

    REMOVABLE_STATUSES = %w[pending resolved priced].freeze

    def self.call!(line:, session:, actor:)
      new(line:, session:, actor:).call!
    end

    def initialize(line:, session:, actor:)
      @line = line
      @session = session
      @actor = actor
    end

    def call!
      raise Error, "Session is not editable." unless session.editable?
      raise Error, "Line does not belong to session." unless line.buyback_session_id == session.id
      raise Error, "Only intake/pricing lines can be removed." unless line.status.in?(REMOVABLE_STATUSES)

      line_id = line.id
      line.destroy!
      AuditEvents.record!(
        actor: actor,
        event_name: "buyback.line.removed",
        auditable: session,
        source: session,
        details: { "line_id" => line_id }
      )
      true
    end

    private

    attr_reader :line, :session, :actor
  end
end
