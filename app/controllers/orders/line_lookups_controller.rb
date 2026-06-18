# frozen_string_literal: true

module Orders
  class LineLookupsController < BaseController
    before_action -> { authorize!("orders.access") }

    def show
      vendor = Vendor.active_records.find_by(id: params[:vendor_id]) if params[:vendor_id].present?
      purchase_order = PurchaseOrder.where(store: orders_store).find_by(id: params[:purchase_order_id]) if params[:purchase_order_id].present?

      result = Purchasing::LineLookup.call(
        store: orders_store,
        query: params[:q],
        mode: params[:mode].presence || :exact,
        vendor: vendor,
        context: params[:context].presence || :order,
        purchase_order: purchase_order,
        eligible_only: eligible_only_for_context(params[:context])
      )

      render json: Purchasing::LineLookupPresenter.as_json(
        result,
        store: orders_store,
        vendor: vendor,
        purchase_order: purchase_order
      )
    end

    private

    def eligible_only_for_context(context)
      %w[direct_receive rtv].include?(context.to_s)
    end
  end
end
