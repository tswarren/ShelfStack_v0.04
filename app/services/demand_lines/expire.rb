# frozen_string_literal: true

module DemandLines
  class Expire
    class ExpireError < StandardError; end

    def self.call!(demand_line:, actor:)
      new(demand_line:, actor:).call!
    end

    def initialize(demand_line:, actor:)
      @demand_line = demand_line
      @actor = actor
    end

    def call!
      raise ExpireError, "Demand line is already terminal" if demand_line.terminal?
      raise ExpireError, "Only open demand lines can be expired" unless demand_line.status == "open"

      DemandLine.transaction do
        demand_line.update!(
          status: "expired",
          expired_by_user: actor,
          expired_at: Time.current
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_line.expired",
          auditable: demand_line,
          details: { "demand_number" => demand_line.demand_number }
        )
      end

      demand_line
    end

    private

    attr_reader :demand_line, :actor
  end
end
