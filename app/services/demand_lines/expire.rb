# frozen_string_literal: true

module DemandLines
  class Expire
    class ExpireError < StandardError; end

    EXPIRABLE_STATUSES = DemandLine::ALLOCATION_ACTIVE_STATUSES.freeze

    def self.call!(demand_line:, actor:)
      new(demand_line:, actor:).call!
    end

    def initialize(demand_line:, actor:)
      @demand_line = demand_line
      @actor = actor
    end

    def call!
      raise ExpireError, "Demand line is already terminal" if demand_line.terminal?
      raise ExpireError, "Demand line is not eligible for manual expiry" unless EXPIRABLE_STATUSES.include?(demand_line.status)

      DemandLine.transaction do
        locked = DemandLine.lock.find(demand_line.id)

        locked.demand_allocations.active_allocations.find_each do |allocation|
          DemandAllocations::Expire.call!(allocation: allocation, actor: actor)
        end

        locked.reload.update!(
          status: "expired",
          expired_by_user: actor,
          expired_at: Time.current
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_line.expired",
          auditable: locked,
          details: { "demand_number" => locked.demand_number }
        )
      end

      demand_line.reload
    end

    private

    attr_reader :demand_line, :actor
  end
end
