# frozen_string_literal: true

module DemandLines
  class Cancel
    class CancelError < StandardError; end

    def self.call!(demand_line:, actor:, cancel_reason: nil)
      new(demand_line:, actor:, cancel_reason:).call!
    end

    def initialize(demand_line:, actor:, cancel_reason: nil)
      @demand_line = demand_line
      @actor = actor
      @cancel_reason = cancel_reason
    end

    def call!
      raise CancelError, "Demand line is already terminal" if demand_line.terminal?

      DemandLine.transaction do
        demand_line.update!(
          status: "canceled",
          canceled_by_user: actor,
          canceled_at: Time.current,
          cancel_reason: cancel_reason
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_line.canceled",
          auditable: demand_line,
          details: { "demand_number" => demand_line.demand_number, "cancel_reason" => cancel_reason }
        )
      end

      demand_line
    end

    private

    attr_reader :demand_line, :actor, :cancel_reason
  end
end
