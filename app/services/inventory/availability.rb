# frozen_string_literal: true

module Inventory
  class Availability
    def self.on_hand(store:, variant:)
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      balance&.quantity_on_hand || 0
    end

    def self.available(store:, variant:)
      return nil unless Eligibility.eligible?(variant)

      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      balance&.quantity_available || 0
    end

    def self.product_on_hand(store:, product:)
      product.product_variants.active_records.sum do |variant|
        next 0 unless Eligibility.eligible?(variant)

        on_hand(store: store, variant: variant)
      end
    end
  end
end
