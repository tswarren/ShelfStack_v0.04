# frozen_string_literal: true

module DemandAllocations
  class Expire
    class ExpireError < StandardError; end

    def self.call!(allocation:, actor: nil, expired_at: nil)
      new(allocation:, actor:, expired_at:).call!
    end

    def initialize(allocation:, actor: nil, expired_at: nil)
      @allocation = allocation
      @actor = actor
      @expired_at = expired_at || Time.current
    end

    def call!
      raise ExpireError, "Allocation is not active" unless allocation.active?

      DemandLine.transaction do
        locked_allocation = DemandAllocation.lock.find(allocation.id)
        raise ExpireError, "Allocation is not active" unless locked_allocation.active?

        locked_allocation.update!(
          status: "expired",
          expired_by_user: actor,
          expired_at: expired_at
        )

        demand_line = DemandLine.lock.find(locked_allocation.demand_line_id)

        AuditEvents.record!(
          actor: actor || User.find_by!(username: ShelfStack::SYSTEM_USERNAME),
          event_name: "demand_allocation.expired",
          auditable: locked_allocation,
          details: {
            "demand_number" => demand_line.demand_number,
            "system_expiry" => actor.nil?
          }
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

    attr_reader :allocation, :actor, :expired_at
  end
end
