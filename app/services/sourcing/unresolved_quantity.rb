# frozen_string_literal: true

module Sourcing
  module UnresolvedQuantity
    module_function

    def for_demand_line(demand_line)
      total = demand_line.quantity_requested -
              fulfilled_qty(demand_line) -
              active_on_hand_qty(demand_line) -
              active_inbound_qty(demand_line) -
              active_vendor_backorder_qty(demand_line) -
              in_flight_sourcing_attempt_qty(demand_line)
      [ total, 0 ].max
    end

    # Simpler equivalent using spec formula directly:
    def breakdown(demand_line)
      fulfilled = fulfilled_qty(demand_line)
      {
        quantity_requested: demand_line.quantity_requested,
        fulfilled_allocation_qty: fulfilled,
        active_on_hand_allocation_qty: active_on_hand_qty(demand_line),
        active_inbound_purchase_order_allocation_qty: active_inbound_qty(demand_line),
        active_vendor_backorder_allocation_qty: active_vendor_backorder_qty(demand_line),
        in_flight_sourcing_attempt_qty: in_flight_sourcing_attempt_qty(demand_line),
        unresolved_for_sourcing: for_demand_line(demand_line)
      }
    end

    def for_sourcing_run(sourcing_run)
      committed = sourcing_run.sourcing_attempts.in_flight.sum(:quantity_requested)
      [ sourcing_run.quantity_requested - committed, 0 ].max
    end

    def active_on_hand_qty(demand_line)
      demand_line.demand_allocations.active_allocations.on_hand_kind.sum(:quantity_allocated)
    end

    def active_inbound_qty(demand_line)
      demand_line.demand_allocations.active_allocations.inbound_kind.sum(:quantity_allocated)
    end

    def active_vendor_backorder_qty(demand_line)
      demand_line.demand_allocations.active_allocations.vendor_backorder_kind.sum(:quantity_allocated)
    end

    def fulfilled_qty(demand_line)
      demand_line.demand_allocations.where(status: "fulfilled").sum(:quantity_allocated)
    end

    def in_flight_sourcing_attempt_qty(demand_line)
      attempts = SourcingAttempt
                 .joins(:sourcing_run)
                 .where(demand_line_id: demand_line.id)
                 .where(sourcing_runs: { status: SourcingRun::ACTIVE_STATUSES })
                 .in_flight

      attempts.sum { |attempt| in_flight_qty_for_attempt(attempt) }
    end

    def in_flight_qty_for_attempt(attempt)
      covered = final_response_covered_qty(attempt)
      [ attempt.quantity_requested - covered, 0 ].max
    end

    def final_response_covered_qty(attempt)
      response = attempt.vendor_responses.where(final_response: true).order(responded_at: :desc).first
      return 0 if response.blank?

      response.quantity_total
    end
  end
end
