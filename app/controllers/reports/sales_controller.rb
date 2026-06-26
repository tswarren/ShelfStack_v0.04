# frozen_string_literal: true

module Reports
  class SalesController < BaseController
    include Reports::SalesSummaryCsv

    before_action -> { authorize_report!("pos.reports.sales") }

    def show
      @transactions = Reports::InclusionRules.pos_sales_transactions(store: report_store)
        .where(transaction_type: "sale")
        .order(completed_at: :desc)
        .limit(100)

      respond_to do |format|
        format.html
        format.csv do
          authorize_report!("pos.reports.export")
          send_data sales_csv(@transactions), filename: "pos-sales-#{Date.current}.csv", type: "text/csv"
        end
      end
    end
  end
end
