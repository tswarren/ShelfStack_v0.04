# frozen_string_literal: true

module Inventory
  class Valuation
    def self.store_totals(store:)
      balances = InventoryBalance.where(store: store)
      {
        quantity_on_hand: balances.sum(:quantity_on_hand),
        inventory_cost_value_cents: balances.sum(:inventory_cost_value_cents),
        inventory_retail_value_cents: balances.sum(:inventory_retail_value_cents)
      }
    end

    def self.enterprise_totals(stores:)
      balances = InventoryBalance.where(store: stores)
      {
        quantity_on_hand: balances.sum(:quantity_on_hand),
        inventory_cost_value_cents: balances.sum(:inventory_cost_value_cents),
        inventory_retail_value_cents: balances.sum(:inventory_retail_value_cents)
      }
    end
  end
end
