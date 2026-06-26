# frozen_string_literal: true

require "csv"

module Pos
  class ReportsController < BaseController
    before_action -> { authorize_pos!("pos.reports.view") }

    def index
      redirect_to reports_root_path, status: :found
    end

    def summary
      redirect_to reports_sales_summary_path(report_redirect_params), status: :found
    end

    def register_summary
      redirect_to reports_register_summary_path(report_redirect_params), status: :found
    end

    def sales
      redirect_to reports_sales_path(report_redirect_params), status: :found
    end

    def returns
      redirect_to reports_returns_path(report_redirect_params), status: :found
    end

    def drawer
      redirect_to reports_cash_drawer_path(report_redirect_params), status: :found
    end

    def operational_margin
      redirect_to reports_operational_margin_path(report_redirect_params), status: :found
    end

    private

    def report_redirect_params
      params.permit(:filter_type, :register_session_id, :business_date, :start_date, :end_date, :session_id, :format)
    end
  end
end
