# frozen_string_literal: true

module Inventory
  class Availability
    def self.on_hand(store:, variant:)
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      balance&.quantity_on_hand || 0
    end

    def self.available(store:, variant:)
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      balance&.quantity_available || 0
    end
  end
end
