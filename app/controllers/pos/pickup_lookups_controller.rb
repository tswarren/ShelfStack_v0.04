# frozen_string_literal: true

module Pos
  class PickupLookupsController < BaseController
    before_action -> { authorize_pos!("pos.fulfill_customer_reservation") }

    def create
      rows = CustomerPickupLookup.ready_for_store(
        store: pos_store,
        query: params[:query],
        request_number: params[:request_number]
      )

      render json: { pickups: PickupLookupPresenter.as_json(rows) }
    end
  end
end
