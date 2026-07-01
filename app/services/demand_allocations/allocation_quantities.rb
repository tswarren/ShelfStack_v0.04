# frozen_string_literal: true

module DemandAllocations
  module AllocationQuantities
    module_function

    def for_demand_line(demand_line)
      active = demand_line.demand_allocations.active_allocations.sum(:quantity_allocated)
      fulfilled = demand_line.demand_allocations.where(status: "fulfilled").sum(:quantity_allocated)
      {
        active_allocated_quantity: active,
        fulfilled_quantity: fulfilled,
        remaining_to_fulfill: [ demand_line.quantity_requested - fulfilled, 0 ].max,
        unallocated_quantity: [
          demand_line.quantity_requested - active - fulfilled,
          0
        ].max
      }
    end

    def active_on_hand_for(store:, variant:)
      DemandAllocation.active_allocations
                      .on_hand_kind
                      .where(store: store, product_variant: variant)
                      .sum(:quantity_allocated)
    end
  end
end
