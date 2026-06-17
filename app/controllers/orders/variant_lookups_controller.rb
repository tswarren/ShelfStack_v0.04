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
      render json: Inventory::VariantLookupPresenter.as_json(result, store: orders_store)
    end
  end
end
