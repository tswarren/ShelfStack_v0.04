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

    def self.reserved(store:, variant:)
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      balance&.quantity_reserved || 0
    end

    def self.reserved_incoming(store:, variant:)
      DemandAllocation.active_allocations
                      .inbound_kind
                      .where(store: store, product_variant: variant)
                      .sum(:quantity_allocated)
    end

    def self.on_order_available(store:, variant:)
      po_qty = Purchasing::OrderQuantityLookup.for_variant(store: store, variant: variant).on_order
      [ po_qty - reserved_incoming(store: store, variant: variant), 0 ].max
    end

    def self.product_on_hand(store:, product:)
      product.product_variants.active_records.sum do |variant|
        next 0 unless Eligibility.eligible?(variant)

        on_hand(store: store, variant: variant)
      end
    end
  end
end
