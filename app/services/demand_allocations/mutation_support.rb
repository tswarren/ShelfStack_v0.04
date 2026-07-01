# frozen_string_literal: true

module DemandAllocations
  module MutationSupport
    module_function

    def ensure_allocatable_demand!(demand_line)
      raise ArgumentError, "Demand line is terminal" if demand_line.terminal?
      raise ArgumentError, "Captured demand cannot be allocated" if demand_line.status == "captured"
      raise ArgumentError, "Demand line requires a variant" if demand_line.product_variant_id.blank?
    end

    def ensure_quantity_within_unallocated_demand!(demand_line:, quantity:, error_class: StandardError)
      remaining = AllocationQuantities.for_demand_line(demand_line)[:unallocated_quantity]
      return remaining if quantity <= remaining

      raise error_class, "Quantity exceeds unallocated demand quantity (#{remaining})"
    end

    def lock_demand_and_allocation!(demand_line_id:, allocation_id:)
      locked_demand = DemandLine.lock.find(demand_line_id)
      locked_allocation = DemandAllocation.lock.find(allocation_id)
      unless locked_allocation.demand_line_id == locked_demand.id
        raise ArgumentError, "Allocation does not belong to demand line"
      end

      [ locked_demand, locked_allocation ]
    end

    def finalize_on_hand_mutation!(demand_line:, actor:, store:, variant:)
      DemandLines::RecalculateAllocationStatus.call!(demand_line: demand_line.reload, actor: actor)
      Inventory::RebuildAvailabilityCache.call!(store: store, product_variant: variant)
    end

    def finalize_inbound_mutation!(demand_line:, actor:)
      DemandLines::RecalculateAllocationStatus.call!(demand_line: demand_line.reload, actor: actor)
    end
  end
end
