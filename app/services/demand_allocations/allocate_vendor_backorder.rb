# frozen_string_literal: true

module DemandAllocations
  class AllocateVendorBackorder
    class AllocateError < StandardError; end

    def self.call!(demand_line:, actor:, quantity:, sourcing_attempt: nil, vendor_response: nil, notes: nil)
      new(
        demand_line:, actor:, quantity:, sourcing_attempt:, vendor_response:, notes:
      ).call!
    end

    def initialize(demand_line:, actor:, quantity:, sourcing_attempt: nil, vendor_response: nil, notes: nil)
      @demand_line = demand_line
      @actor = actor
      @quantity = quantity.to_i
      @sourcing_attempt = sourcing_attempt
      @vendor_response = vendor_response
      @notes = notes
    end

    def call!
      raise AllocateError, "Quantity must be positive" unless quantity.positive?
      raise AllocateError, "Sourcing attempt or vendor response reference is required" if sourcing_attempt.blank? && vendor_response.blank?

      allocation = nil

      DemandLine.transaction do
        locked_demand = DemandLine.lock.find(demand_line.id)
        MutationSupport.ensure_allocatable_demand!(locked_demand, error_class: AllocateError)
        MutationSupport.ensure_quantity_within_unallocated_demand!(
          demand_line: locked_demand,
          quantity: quantity,
          error_class: AllocateError
        )

        if locked_demand.capture_intent == "used_wanted"
          raise AllocateError, "Used-wanted demand cannot receive vendor backorder allocations"
        end

        allocation = DemandAllocation.create!(
          store: locked_demand.store,
          demand_line: locked_demand,
          product: locked_demand.product,
          product_variant: locked_demand.product_variant,
          allocation_kind: "vendor_backorder",
          status: "active",
          quantity_allocated: quantity,
          sourcing_attempt: sourcing_attempt,
          vendor_response: vendor_response,
          allocated_by_user: actor,
          allocated_at: Time.current,
          notes: notes
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_allocation.vendor_backorder_created",
          auditable: allocation,
          details: {
            "demand_number" => locked_demand.demand_number,
            "quantity_allocated" => quantity,
            "sourcing_attempt_id" => sourcing_attempt&.id,
            "vendor_response_id" => vendor_response&.id
          }
        )

        MutationSupport.finalize_vendor_backorder_mutation!(demand_line: locked_demand, actor: actor)
      end

      allocation.reload
    end

    private

    attr_reader :demand_line, :actor, :quantity, :sourcing_attempt, :vendor_response, :notes
  end
end
