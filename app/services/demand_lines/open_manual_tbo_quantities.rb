# frozen_string_literal: true

module DemandLines
  class OpenManualTboQuantities
    def self.for_variants(store:, variant_ids:)
      new(store:, variant_ids:).quantities_by_variant_id
    end

    def initialize(store:, variant_ids:)
      @store = store
      @variant_ids = Array(variant_ids).compact.uniq
    end

    def quantities_by_variant_id
      return {} if store.blank? || variant_ids.empty?

      counts = Hash.new(0)
      DemandLine.where(store: store, product_variant_id: variant_ids, capture_intent: "manual_tbo")
                .where.not(status: DemandLine::TERMINAL_STATUSES)
                .find_each do |line|
        unallocated = DemandAllocations::AllocationQuantities.for_demand_line(line)[:unallocated_quantity]
        counts[line.product_variant_id] += unallocated
      end
      counts
    end

    private

    attr_reader :store, :variant_ids
  end
end
