# frozen_string_literal: true

module Reports
  class StoredValueController < BaseController
    before_action -> { authorize_report!("stored_value.reports.view") }

    def show
      @report = StoredValue::LiabilityReport.call(store: report_store, date_range: build_date_range)
    end

    private

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
