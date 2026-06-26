# frozen_string_literal: true

module Reports
  class SalesSummaryController < BaseController
    include Reports::PosScopeReporting
    include Reports::SalesSummaryCsv

    before_action -> { authorize_report!("pos.reports.summary") }
    before_action :load_pos_scope_report!, only: :show

    def show
      @report = @scope && Pos::SalesRevenueSummaryReport.call(scope: @scope)

      respond_to do |format|
        format.html
        format.csv do
          authorize_report!("pos.reports.export")
          send_data summary_csv(@report), filename: summary_csv_filename, type: "text/csv"
        end
      end
    end
  end
end
