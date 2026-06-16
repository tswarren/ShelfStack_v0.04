# frozen_string_literal: true

module Inventory
  class EnterpriseController < BaseController
    before_action -> { authorize!("inventory.enterprise.view") }

    def index
      @stores = Authorization.accessible_stores(user: current_user, permission_key: "inventory.enterprise.view")
      @totals = Inventory::Valuation.enterprise_totals(stores: @stores)
      @balances_by_store = InventoryBalance
        .where(store: @stores)
        .group(:store_id)
        .select("store_id, SUM(quantity_on_hand) AS total_on_hand, SUM(inventory_retail_value_cents) AS total_retail_cents")
        .index_by(&:store_id)
    end
  end
end
