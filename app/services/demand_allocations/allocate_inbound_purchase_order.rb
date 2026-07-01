# frozen_string_literal: true

module DemandAllocations
  class AllocateInboundPurchaseOrder
    class AllocateError < StandardError; end

    def self.call!(demand_line:, purchase_order_line:, actor:, quantity:, notes: nil)
      new(demand_line:, purchase_order_line:, actor:, quantity:, notes:).call!
    end

    def initialize(demand_line:, purchase_order_line:, actor:, quantity:, notes: nil)
      @demand_line = demand_line
      @purchase_order_line = purchase_order_line
      @actor = actor
      @quantity = quantity.to_i
      @notes = notes
    end

    def call!
      raise AllocateError, "Quantity must be positive" unless quantity.positive?

      allocation = nil

      DemandLine.transaction do
        locked_demand = DemandLine.lock.find(demand_line.id)
        locked_po_line = PurchaseOrderLine.lock.find(purchase_order_line.id)

        MutationSupport.ensure_allocatable_demand!(locked_demand)

        if locked_demand.store_id != locked_po_line.purchase_order.store_id
          raise AllocateError, "Purchase order line must belong to the same store"
        end

        if locked_demand.product_variant_id != locked_po_line.product_variant_id
          raise AllocateError, "Purchase order line variant must match demand line"
        end

        inbound = InboundAvailability.new(purchase_order_line: locked_po_line)
        raise AllocateError, "Purchase order line is not eligible for inbound allocation" unless inbound.eligible?

        available = inbound.available_for
        raise AllocateError, "Insufficient inbound quantity (#{available})" if quantity > available

        allocation = DemandAllocation.create!(
          store: locked_demand.store,
          demand_line: locked_demand,
          product: locked_demand.product,
          product_variant: locked_demand.product_variant,
          allocation_kind: "inbound_purchase_order",
          status: "active",
          quantity_allocated: quantity,
          purchase_order_line: locked_po_line,
          allocated_by_user: actor,
          allocated_at: Time.current,
          notes: notes
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_allocation.created",
          auditable: allocation,
          details: {
            "demand_number" => locked_demand.demand_number,
            "allocation_kind" => "inbound_purchase_order",
            "quantity_allocated" => quantity,
            "purchase_order_line_id" => locked_po_line.id
          }
        )

        MutationSupport.finalize_inbound_mutation!(demand_line: locked_demand, actor: actor)
      end

      allocation.reload
    end

    private

    attr_reader :demand_line, :purchase_order_line, :actor, :quantity, :notes
  end
end
