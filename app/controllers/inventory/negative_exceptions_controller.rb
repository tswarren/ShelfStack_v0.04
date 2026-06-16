# frozen_string_literal: true

module Inventory
  class NegativeExceptionsController < BaseController
    before_action -> { authorize!("inventory.negative_exceptions.view") }

    def index
      @balances = InventoryBalance
        .negative_on_hand
        .includes(product_variant: :product)
        .where(store: inventory_store)
        .order(:quantity_on_hand)
        .joins(:product_variant)
    end
  end
end
