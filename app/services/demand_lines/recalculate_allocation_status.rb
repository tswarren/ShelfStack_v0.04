# frozen_string_literal: true

module DemandLines
  class RecalculateAllocationStatus
    class RecalculateError < StandardError; end

    NON_RECALCULABLE = %w[captured canceled expired].freeze

    def self.call!(demand_line:, actor: nil)
      new(demand_line:, actor:).call!
    end

    def initialize(demand_line:, actor: nil)
      @demand_line = demand_line
      @actor = actor
    end

    def call!
      return demand_line if NON_RECALCULABLE.include?(demand_line.status)

      quantities = DemandAllocations::AllocationQuantities.for_demand_line(demand_line)
      new_status = resolve_status(quantities)

      return demand_line if demand_line.status == new_status

      demand_line.update!(status: new_status)

      if actor.present?
        AuditEvents.record!(
          actor: actor,
          event_name: "demand_line.allocation_status_recalculated",
          auditable: demand_line,
          details: {
            "demand_number" => demand_line.demand_number,
            "status" => new_status,
            "active_allocated_quantity" => quantities[:active_allocated_quantity],
            "fulfilled_quantity" => quantities[:fulfilled_quantity]
          }
        )
      end

      demand_line
    end

    private

    attr_reader :demand_line, :actor

    def resolve_status(quantities)
      requested = demand_line.quantity_requested
      active = quantities[:active_allocated_quantity]
      fulfilled = quantities[:fulfilled_quantity]
      remaining = quantities[:remaining_to_fulfill]

      if fulfilled >= requested
        "fulfilled"
      elsif active >= remaining && remaining.positive?
        "allocated"
      elsif active.positive? || fulfilled.positive?
        "partially_allocated"
      else
        "open"
      end
    end
  end
end
