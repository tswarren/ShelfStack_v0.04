# frozen_string_literal: true

module Customers
  class StoredValueReportsController < BaseController
    before_action -> { authorize!("stored_value.reports.view") }

    def index
      date_range = build_date_range
      @report = StoredValue::LiabilityReport.call(store: report_store, date_range: date_range)
    end

    private

    def report_store
      params[:store_scope] == "all" ? nil : customers_store
    end

    def build_date_range
      return nil if params[:start_date].blank? && params[:end_date].blank?

      start_date = params[:start_date].present? ? Date.parse(params[:start_date]).beginning_of_day : nil
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]).end_of_day : Time.current
      start_date..end_date
    rescue ArgumentError
      nil
    end
  end
end
