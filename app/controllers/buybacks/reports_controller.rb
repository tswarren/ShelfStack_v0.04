# frozen_string_literal: true

module Buybacks
  class ReportsController < BaseController
    before_action -> { authorize_buyback!("buybacks.reports.view") }

    def index
      redirect_to reports_buyback_summary_path(request.query_parameters), status: :found
    end
  end
end
