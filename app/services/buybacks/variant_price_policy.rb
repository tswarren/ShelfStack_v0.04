# frozen_string_literal: true

module Buybacks
  class VariantPricePolicy
    def self.updatable_from_buyback?(variant:, store:)
      new(variant:, store:).updatable_from_buyback?
    end

    def initialize(variant:, store:)
      @variant = variant
      @store = store
    end

    def updatable_from_buyback?
      on_hand_quantity.zero?
    end

    private

    attr_reader :variant, :store

    def on_hand_quantity
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      balance&.quantity_on_hand.to_i
    end
  end
end
