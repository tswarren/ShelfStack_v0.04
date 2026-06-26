# frozen_string_literal: true

module Reports
  class PurchasingSummaryController < BaseController
    before_action -> { authorize_report!("orders.access") }

    def show
      @report = PurchasingSummary::Query.call(
        store: report_store,
        start_date: parse_date(params[:start_date]),
        end_date: parse_date(params[:end_date])
      )
    end

    private

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
