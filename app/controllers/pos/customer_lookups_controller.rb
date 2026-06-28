# frozen_string_literal: true

module Pos
  class CustomerLookupsController < BaseController
    def show
      result = Customers::CustomerLookup.call(
        query: params[:q],
        mode: params[:mode].presence || :exact
      )

      render json: Customers::CustomerLookupPresenter.as_json(result)
    end
  end
end
