# frozen_string_literal: true

module Reports
  class DemandQueueController < BaseController
    before_action -> { authorize_report!("demand.access") }

    def show
      @report = DemandQueue::Query.call(
        store: report_store,
        queue: params[:queue],
        status: params[:status]
      )
    end
  end
end
