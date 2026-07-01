# frozen_string_literal: true

module Customers
  class CustomerLookupsController < BaseController
    before_action :authorize_lookup!

    def show
      result = Customers::CustomerLookup.call(
        query: params[:q],
        mode: params[:mode].presence || :exact
      )

      render json: Customers::CustomerLookupPresenter.as_json(result)
    end

    private

    def authorize_lookup!
      keys = %w[customers.access customer_requests.access demand.create]
      return if keys.any? { |key| Authorization.allowed?(user: current_user, permission_key: key, store: current_store) }

      redirect_back fallback_location: customers_root_path, alert: "You are not authorized for this action."
    end
  end
end
