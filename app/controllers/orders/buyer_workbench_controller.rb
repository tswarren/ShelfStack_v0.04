# frozen_string_literal: true

module Orders
  class BuyerWorkbenchController < BaseController
    before_action -> { authorize!("orders.purchase_orders.view") }

    def index
      @tab = params[:tab].presence || "needs_ordering"
      @tab_counts = DemandLines::BuyerWorkbenchScope.counts_for(store: orders_store)
      relation = DemandLines::BuyerWorkbenchScope.base_relation(store: orders_store)
      relation = DemandLines::BuyerWorkbenchScope.apply(relation, @tab, store: orders_store)
      @demand_lines = relation.order(updated_at: :desc).limit(200)
      @rows = build_rows(@demand_lines, @tab)
    end

    private

    def build_rows(demand_lines, tab)
      variant_ids = demand_lines.filter_map(&:product_variant_id).uniq
      vendors_by_variant = Purchasing::SuggestedVendorResolver.for_variants(variant_ids)

      demand_lines.map do |line|
        BuyerWorkbenchRowPresenter.new(
          demand_line: line,
          store: orders_store,
          tab_key: tab,
          suggested_vendor: vendors_by_variant[line.product_variant_id]
        )
      end
    end
  end
end
