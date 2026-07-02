# frozen_string_literal: true

module Pos
  class LineLookupPresenter
    def self.as_json(result, store:)
      new(result, store:).as_json
    end

    def initialize(result, store:)
      @result = result
      @store = store
    end

    def as_json
      {
        status: result.status.to_s,
        message: result.message,
        variants: result.variants.map { |variant| variant_json(variant) }
      }
    end

    private

    attr_reader :result, :store

    def variant_json(variant)
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      on_hand = balance&.quantity_on_hand || 0
      available = Inventory::Availability.available(store: store, variant: variant) || 0
      reserved = Inventory::Availability.reserved(store: store, variant: variant)
      ready_allocations = ready_allocations_for(variant)

      {
        id: variant.id,
        sku: variant.sku,
        name: variant.name,
        product_name: variant.product.name,
        condition: variant.condition&.short_name,
        selling_price_cents: variant.selling_price_cents,
        inventory_behavior: variant.inventory_behavior,
        inventory_tracking: Inventory::TrackingResolver.resolve(variant),
        active: variant.active?,
        product_active: variant.product.active?,
        quantity_on_hand: on_hand,
        quantity_available: available,
        quantity_reserved: reserved,
        ready_allocations: ready_allocations
      }
    end

    def ready_allocations_for(variant)
      DemandAllocation.active_allocations
                      .on_hand_kind
                      .where(store: store, product_variant: variant)
                      .where("demand_allocations.expires_at IS NULL OR demand_allocations.expires_at > ?", Time.current)
                      .joins(:demand_line)
                      .merge(DemandLine.where.not(status: DemandLine::TERMINAL_STATUSES))
                      .includes(demand_line: :customer)
                      .limit(10)
                      .map do |allocation|
        demand_line = allocation.demand_line
        {
          id: allocation.id,
          customer_name: CustomerDemand::DisplayName.for_demand_line(demand_line),
          demand_number: demand_line.demand_number,
          expires_at: allocation.expires_at&.iso8601,
          quantity: allocation.quantity_allocated
        }
      end
    end
  end
end
