# frozen_string_literal: true

module Inventory
  class VariantLookupPresenter
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
      {
        id: variant.id,
        sku: variant.sku,
        name: variant.name,
        condition: variant.condition&.short_name,
        inventory_behavior: variant.inventory_behavior,
        eligible: Inventory::Eligibility.eligible?(variant),
        quantity_on_hand: balance&.quantity_on_hand || 0
      }
    end
  end
end
