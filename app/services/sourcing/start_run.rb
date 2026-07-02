# frozen_string_literal: true

module Sourcing
  class StartRun
    class StartRunError < StandardError; end

    def self.call!(demand_line:, actor:, quantity: nil, notes: nil)
      new(demand_line:, actor:, quantity:, notes:).call!
    end

    def initialize(demand_line:, actor:, quantity: nil, notes: nil)
      @demand_line = demand_line
      @actor = actor
      @quantity = quantity
      @notes = notes
    end

    def call!
      eligibility = Eligibility.for_demand_line(demand_line)
      raise StartRunError, eligibility.reason unless eligibility.eligible

      unresolved = UnresolvedQuantity.for_demand_line(demand_line)
      qty = quantity || unresolved
      raise StartRunError, "Quantity must be positive" unless qty.to_i.positive?
      raise StartRunError, "Quantity exceeds unresolved sourcing quantity (#{unresolved})" if qty.to_i > unresolved

      run = nil
      DemandLine.transaction do
        locked_demand = DemandLine.lock.find(demand_line.id)
        locked_eligibility = Eligibility.for_demand_line(locked_demand)
        raise StartRunError, locked_eligibility.reason unless locked_eligibility.eligible

        locked_unresolved = UnresolvedQuantity.for_demand_line(locked_demand)
        raise StartRunError, "Quantity exceeds unresolved sourcing quantity (#{locked_unresolved})" if qty.to_i > locked_unresolved

        now = Time.current
        run = SourcingRun.create!(
          store: locked_demand.store,
          demand_line: locked_demand,
          product: locked_demand.product,
          product_variant: locked_demand.product_variant,
          status: "open",
          quantity_requested: qty.to_i,
          started_by_user: actor,
          started_at: now,
          notes: notes
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "sourcing_run.created",
          auditable: run,
          details: {
            "demand_number" => locked_demand.demand_number,
            "sourcing_run_id" => run.id,
            "quantity_requested" => qty.to_i
          }
        )
      end

      run.reload
    end

    private

    attr_reader :demand_line, :actor, :quantity, :notes
  end
end
