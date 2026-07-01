# frozen_string_literal: true

module InventoryReservations
  class RebuildReservedQuantities
    def self.call!(store: nil)
      Inventory::RebuildAvailabilityCache.for_all!(store: store)
    end
  end
end
