# frozen_string_literal: true

module DemandAllocations
  class Release
    class ReleaseError < StandardError; end

    def self.call!(allocation:, actor:, release_reason: nil)
      new(allocation:, actor:, release_reason:).call!
    end

    def initialize(allocation:, actor:, release_reason: nil)
      @allocation = allocation
      @actor = actor
      @release_reason = release_reason
    end

    def call!
      raise ReleaseError, "Allocation is not active" unless allocation.active?

      DemandLine.transaction do
        demand_line, locked_allocation = MutationSupport.lock_demand_and_allocation!(
          demand_line_id: allocation.demand_line_id,
          allocation_id: allocation.id
        )
        raise ReleaseError, "Allocation is not active" unless locked_allocation.active?

        locked_allocation.update!(
          status: "released",
          released_by_user: actor,
          released_at: Time.current,
          release_reason: release_reason
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_allocation.released",
          auditable: locked_allocation,
          details: { "demand_number" => demand_line.demand_number, "release_reason" => release_reason }
        )

        if locked_allocation.on_hand?
          MutationSupport.finalize_on_hand_mutation!(
            demand_line: demand_line,
            actor: actor,
            store: locked_allocation.store,
            variant: locked_allocation.product_variant
          )
        else
          MutationSupport.finalize_inbound_mutation!(demand_line: demand_line, actor: actor)
        end
      end

      allocation.reload
    end

    private

    attr_reader :allocation, :actor, :release_reason
  end
end
