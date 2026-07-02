# frozen_string_literal: true

module DemandLines
  class SurfaceNotifyLines
    def self.for_variant(store:, variant:, actor: nil)
      new(store:, variant:, actor:).call
    end

    def initialize(store:, variant:, actor: nil)
      @store = store
      @variant = variant
      @actor = actor
    end

    def call
      return if Inventory::Availability.available(store: store, variant: variant).to_i <= 0

      matching_demand_lines.find_each do |demand_line|
        DemandLines::RecalculateAllocationStatus.call!(demand_line: demand_line, actor: actor)
      end
    end

    private

    attr_reader :store, :variant, :actor

    def matching_demand_lines
      DemandLine.where(store: store, product_variant: variant, capture_intent: "notify")
                .where(status: DemandLine::ALLOCATION_ACTIVE_STATUSES)
    end
  end
end
