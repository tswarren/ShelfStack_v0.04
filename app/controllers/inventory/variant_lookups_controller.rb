# frozen_string_literal: true

module Inventory
  class VariantLookupsController < BaseController
    before_action -> { authorize!("inventory.adjustments.create") }

    def show
      result = VariantLookup.call(query: params[:q], mode: params[:mode].presence || :exact)
      render json: VariantLookupPresenter.as_json(result, store: inventory_store)
    end
  end
end
