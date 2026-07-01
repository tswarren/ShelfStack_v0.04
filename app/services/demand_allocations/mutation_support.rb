# frozen_string_literal: true

module DemandAllocations
  module MutationSupport
    module_function

    def ensure_allocatable_demand!(demand_line)
      raise ArgumentError, "Demand line is terminal" if demand_line.terminal?
      raise ArgumentError, "Captured demand cannot be allocated" if demand_line.status == "captured"
      raise ArgumentError, "Demand line requires a variant" if demand_line.product_variant_id.blank?
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
