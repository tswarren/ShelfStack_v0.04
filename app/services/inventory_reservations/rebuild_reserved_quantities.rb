# frozen_string_literal: true

module InventoryReservations
  class RebuildReservedQuantities
    def self.call!(store: nil)
      new(store:).call!
    end

    def initialize(store: nil)
      @store = store
    end

    def call!
      scope = InventoryBalance.all
      scope = scope.where(store: store) if store.present?

      scope.find_each do |balance|
        reserved = InventoryReservation.active_on_hand
                                       .where(store: balance.store, product_variant: balance.product_variant)
                                       .sum("quantity_reserved - quantity_fulfilled - quantity_released")
        balance.update!(quantity_reserved: reserved, quantity_available: balance.quantity_on_hand - reserved)
      end
    end

    private

    attr_reader :store
  end
end
