# frozen_string_literal: true

module Inventory
  class BalancesController < BaseController
    before_action -> { authorize!("inventory.balances.view") }

    def index
      @balances = InventoryBalance
        .includes(product_variant: :product)
        .where(store: inventory_store)
        .order("product_variants.sku")
        .joins(:product_variant)

      if params[:q].present?
        q = "%#{params[:q].strip}%"
        @balances = @balances.where("product_variants.sku ILIKE :q OR product_variants.name ILIKE :q", q: q)
      end

      @totals = Inventory::Valuation.store_totals(store: inventory_store)
    end
  end
end
