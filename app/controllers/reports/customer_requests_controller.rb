# frozen_string_literal: true

module Reports
  class CustomerRequestsController < BaseController
    before_action -> { authorize_report!("customer_requests.access") }

    def show
      @report = CustomerRequests::Query.call(
        store: report_store,
        queue: params[:queue],
        status: params[:status]
      )
    end
  end
end
