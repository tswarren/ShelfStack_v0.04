# frozen_string_literal: true

module Customers
  class VariantLookupsController < BaseController
    before_action -> { authorize!("customer_requests.access") }

    def show
      result = Inventory::VariantLookup.call(
        query: params[:q],
        mode: params[:mode].presence || :exact,
        eligible_only: ActiveModel::Type::Boolean.new.cast(params.fetch(:eligible_only, false))
      )
      render json: Inventory::VariantLookupPresenter.as_json(result, store: customers_store)
    end
  end
end
