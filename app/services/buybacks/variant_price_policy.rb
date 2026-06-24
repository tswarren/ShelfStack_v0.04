# frozen_string_literal: true

module Buybacks
  class VariantPricePolicy
    def self.updatable_from_buyback?(variant:, store:, session: nil)
      new(variant:, store:, session:).updatable_from_buyback?
    end

    def initialize(variant:, store:, session: nil)
      @variant = variant
      @store = store
      @session = session
    end

    def updatable_from_buyback?
      return true if created_by_session?

      on_hand_quantity.zero?
    end

    private

    attr_reader :variant, :store, :session

    def created_by_session?
      session.present? && variant.created_from_buyback_session_id == session.id
    end

    def on_hand_quantity
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      balance&.quantity_on_hand.to_i
    end
  end
end
