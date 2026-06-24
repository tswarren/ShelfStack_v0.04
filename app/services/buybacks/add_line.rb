# frozen_string_literal: true

module Buybacks
  class AddLine
    def self.call!(session:, actor:, **attrs)
      new(session:, actor:, **attrs).call!
    end

    def initialize(session:, actor:, identifier_entered: nil, title_snapshot: nil, notes: nil)
      @session = session
      @actor = actor
      @identifier_entered = identifier_entered
      @title_snapshot = title_snapshot
      @notes = notes
    end

    def call!
      raise ArgumentError, "Lines can only be added while the session is in draft." unless session.draft?

      line_number = session.buyback_lines.maximum(:line_number).to_i + 1
      line = session.buyback_lines.create!(
        line_number: line_number,
        status: "pending",
        identifier_entered: identifier_entered,
        identifier_normalized: normalize_identifier(identifier_entered),
        title_snapshot: title_snapshot.presence || "Pending item",
        notes: notes
      )

      AuditEvents.record!(actor: actor, event_name: "buyback.line.added", auditable: line, source: session)
      line
    end

    private

    attr_reader :session, :actor, :identifier_entered, :title_snapshot, :notes

    def normalize_identifier(value)
      value.to_s.strip.upcase.gsub(/[^0-9X]/i, "").presence
    end
  end
end
