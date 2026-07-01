# frozen_string_literal: true

module DemandAllocations
  class AllocateOnHand
    class AllocateError < StandardError; end

    def self.call!(demand_line:, actor:, quantity:, override_availability: false, override_reason: nil,
                   override_authorized_by_user: nil, notes: nil)
      new(
        demand_line:, actor:, quantity:, override_availability:, override_reason:,
        override_authorized_by_user:, notes:
      ).call!
    end

    def initialize(demand_line:, actor:, quantity:, override_availability: false, override_reason: nil,
                   override_authorized_by_user: nil, notes: nil)
      @demand_line = demand_line
      @actor = actor
      @quantity = quantity.to_i
      @override_availability = override_availability == true
      @override_reason = override_reason
      @override_authorized_by_user = override_authorized_by_user || (override_availability ? actor : nil)
      @notes = notes
    end

    def call!
      raise AllocateError, "Quantity must be positive" unless quantity.positive?

      store = demand_line.store
      variant = demand_line.product_variant
      allocation = nil

      DemandLine.transaction do
        locked_demand = DemandLine.lock.find(demand_line.id)
        MutationSupport.ensure_allocatable_demand!(locked_demand)

        balance = InventoryBalance.lock.find_or_initialize_by(store: store, product_variant: variant)
        balance.quantity_on_hand ||= 0
        balance.quantity_reserved ||= 0

        available = Availability.available_for_allocation(store: store, variant: variant, balance: balance)

        if quantity > available && !override_availability
          raise AllocateError, "Insufficient available quantity (#{available})"
        end

        if override_availability && override_authorized_by_user.blank?
          raise AllocateError, "Override authorization is required"
        end

        now = Time.current
        allocation = DemandAllocation.create!(
          store: store,
          demand_line: locked_demand,
          product: locked_demand.product,
          product_variant: variant,
          allocation_kind: "on_hand",
          status: "active",
          quantity_allocated: quantity,
          expires_at: locked_demand.expires_at,
          allocated_by_user: actor,
          allocated_at: now,
          override_availability: override_availability == true,
          override_authorized_by_user: override_availability ? override_authorized_by_user : nil,
          override_authorized_at: override_availability ? now : nil,
          override_reason: override_availability ? override_reason : nil,
          notes: notes
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_allocation.created",
          auditable: allocation,
          details: {
            "demand_number" => locked_demand.demand_number,
            "allocation_kind" => "on_hand",
            "quantity_allocated" => quantity,
            "override_availability" => override_availability
          }
        )

        if override_availability
          AuditEvents.record!(
            actor: override_authorized_by_user,
            event_name: "demand_allocation.override_availability_used",
            auditable: allocation,
            details: {
              "demand_number" => locked_demand.demand_number,
              "override_reason" => override_reason
            }
          )
        end

        MutationSupport.finalize_on_hand_mutation!(demand_line: locked_demand, actor: actor, store: store, variant: variant)
      end

      allocation.reload
    end

    private

    attr_reader :demand_line, :actor, :quantity, :override_availability, :override_reason,
                :override_authorized_by_user, :notes
  end
end
