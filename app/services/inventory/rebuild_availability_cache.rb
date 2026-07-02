# frozen_string_literal: true

module Inventory
  class RebuildAvailabilityCache
    def self.call!(store:, product_variant:)
      new(store:, product_variant:).call!
    end

    def self.for_all!(store: nil)
      scope = InventoryBalance.all
      scope = scope.where(store: store) if store.present?

      scope.find_each do |balance|
        call!(store: balance.store, product_variant: balance.product_variant)
      end
    end

    def initialize(store:, product_variant:)
      @store = store
      @product_variant = product_variant
    end

    def call!
      balance = InventoryBalance.find_or_initialize_by(store: store, product_variant: product_variant)
      balance.quantity_on_hand ||= 0
      balance.quantity_reserved = legacy_on_hand_reserved + v0047_on_hand_reserved
      balance.quantity_available = balance.quantity_on_hand - balance.quantity_reserved
      balance.save!
      balance
    end

    private

    attr_reader :store, :product_variant

    def legacy_on_hand_reserved
      InventoryReservation.active_on_hand
                          .where(store: store, product_variant: product_variant)
                          .sum("quantity_reserved - quantity_fulfilled - quantity_released")
    end

    def v0047_on_hand_reserved
      DemandAllocations::AllocationQuantities.active_on_hand_for(store: store, variant: product_variant)
    end
  end
end
