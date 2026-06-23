# frozen_string_literal: true

module Buybacks
  class ReportsController < BaseController
    before_action -> { authorize_buyback!("buybacks.reports.view") }

    def index
      @summary = ReportBuilder.summary(store: buybacks_store, date_range: date_range)
      @activity = ReportBuilder.activity(store: buybacks_store, date_range: date_range)
    end

    private

    def date_range
      return nil if params[:start_date].blank? && params[:end_date].blank?

      start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
      start_date.beginning_of_day..end_date.end_of_day
    rescue Date::Error
      nil
    end
  end
end
