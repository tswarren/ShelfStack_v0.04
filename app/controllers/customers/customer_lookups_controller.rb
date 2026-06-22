# frozen_string_literal: true

module Customers
  class CustomerLookupsController < BaseController
    before_action -> { authorize!("customer_requests.access") }

    def show
      result = Customers::CustomerLookup.call(
        query: params[:q],
        mode: params[:mode].presence || :exact
      )

      render json: Customers::CustomerLookupPresenter.as_json(result)
    end
  end
end
