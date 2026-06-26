# frozen_string_literal: true

module Customers
  class StoredValueReportsController < BaseController
    before_action -> { authorize!("stored_value.reports.view") }

    def index
      redirect_to reports_stored_value_path(request.query_parameters), status: :found
    end
  end
end
