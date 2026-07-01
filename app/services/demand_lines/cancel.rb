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
      raise CancelError, "Fulfilled demand cannot be canceled" if demand_line.status == "fulfilled"

      DemandLine.transaction do
        locked = DemandLine.lock.find(demand_line.id)
        raise CancelError, "Demand line is already terminal" if locked.terminal?

        locked.demand_allocations.active_allocations.find_each do |allocation|
          DemandAllocations::Cancel.call!(
            allocation: allocation,
            actor: actor,
            cancel_reason: cancel_reason.presence || "Demand canceled"
          )
        end

        locked.reload.update!(
          status: "canceled",
          canceled_by_user: actor,
          canceled_at: Time.current,
          cancel_reason: cancel_reason
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_line.canceled",
          auditable: locked,
          details: { "demand_number" => locked.demand_number, "cancel_reason" => cancel_reason }
        )
      end

      demand_line.reload
    end

    private

    attr_reader :demand_line, :actor, :cancel_reason
  end
end
