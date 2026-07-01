# frozen_string_literal: true

module DemandAllocations
  class Cancel
    class CancelError < StandardError; end

    def self.call!(allocation:, actor:, cancel_reason:)
      new(allocation:, actor:, cancel_reason:).call!
    end

    def initialize(allocation:, actor:, cancel_reason:)
      @allocation = allocation
      @actor = actor
      @cancel_reason = cancel_reason
    end

    def call!
      raise CancelError, "Allocation is not active" unless allocation.active?
      raise CancelError, "Cancel reason is required" if cancel_reason.blank?

      DemandLine.transaction do
        locked_allocation = DemandAllocation.lock.find(allocation.id)
        raise CancelError, "Allocation is not active" unless locked_allocation.active?

        locked_allocation.update!(
          status: "canceled",
          canceled_by_user: actor,
          canceled_at: Time.current,
          cancel_reason: cancel_reason
        )

        demand_line = DemandLine.lock.find(locked_allocation.demand_line_id)

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_allocation.canceled",
          auditable: locked_allocation,
          details: { "demand_number" => demand_line.demand_number, "cancel_reason" => cancel_reason }
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

    attr_reader :allocation, :actor, :cancel_reason
  end
end
