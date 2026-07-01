# frozen_string_literal: true

module DemandAllocations
  class Fulfill
    class FulfillError < StandardError; end

    def self.call!(allocation:, actor:, fulfillment_reference: nil)
      new(allocation:, actor:, fulfillment_reference:).call!
    end

    def initialize(allocation:, actor:, fulfillment_reference: nil)
      @allocation = allocation
      @actor = actor
      @fulfillment_reference = fulfillment_reference
    end

    def call!
      raise FulfillError, "Allocation is not active" unless allocation.active?

      DemandLine.transaction do
        locked_allocation = DemandAllocation.lock.find(allocation.id)
        raise FulfillError, "Allocation is not active" unless locked_allocation.active?

        attrs = {
          status: "fulfilled",
          fulfilled_at: Time.current
        }

        if fulfillment_reference.present?
          attrs[:fulfillment_reference_type] = fulfillment_reference.class.name
          attrs[:fulfillment_reference_id] = fulfillment_reference.id
        else
          attrs[:fulfilled_by_user] = actor
        end

        locked_allocation.update!(attrs)

        demand_line = DemandLine.lock.find(locked_allocation.demand_line_id)

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_allocation.fulfilled",
          auditable: locked_allocation,
          details: { "demand_number" => demand_line.demand_number }
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

    attr_reader :allocation, :actor, :fulfillment_reference
  end
end
