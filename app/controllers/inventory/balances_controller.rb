# frozen_string_literal: true

module Inventory
  class BalancesController < BaseController
    before_action -> { authorize!("inventory.balances.view") }

    def index
      result = Inventory::BalancesQuery.call(
        store: inventory_store,
        query: params[:q],
        page: params[:page]
      )

      @balances = result.balances
      @total_count = result.total_count
      @page = result.page
      @per_page = result.per_page
      @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
      @totals = Inventory::Valuation.store_totals(store: inventory_store)
      @order_quantities = Purchasing::OrderQuantityLookup.for_variants(
        store: inventory_store,
        variant_ids: @balances.map(&:product_variant_id)
      )
    end
  end
end
