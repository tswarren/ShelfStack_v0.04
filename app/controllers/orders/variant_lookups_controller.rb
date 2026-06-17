# frozen_string_literal: true

module Orders
  class VariantLookupsController < BaseController
    before_action -> { authorize!("orders.access") }

    def show
      result = Inventory::VariantLookup.call(
        query: params[:q],
        mode: params[:mode].presence || :exact,
        eligible_only: ActiveModel::Type::Boolean.new.cast(params.fetch(:eligible_only, true))
      )
      vendor = Vendor.find_by(id: params[:vendor_id]) if params[:vendor_id].present?
      render json: Inventory::VariantLookupPresenter.as_json(result, store: orders_store, vendor: vendor)
    end
  end
end
