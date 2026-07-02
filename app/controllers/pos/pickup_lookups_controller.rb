# frozen_string_literal: true

module Pos
  class PickupLookupsController < BaseController
    before_action -> { authorize_pos!("pos.fulfill_customer_reservation") }

    def create
      rows = DemandPickupLookup.ready_for_store(
        store: pos_store,
        query: params[:query],
        demand_number: params[:demand_number].presence || params[:request_number]
      )

      render json: { pickups: PickupLookupPresenter.as_json(rows) }
    end
  end
end
