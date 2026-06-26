# frozen_string_literal: true

module Reports
  class ReturnsController < BaseController
    include Reports::SalesSummaryCsv

    before_action -> { authorize_report!("pos.reports.returns") }

    def show
      @transactions = Reports::InclusionRules.pos_sales_transactions(store: report_store)
        .where(transaction_type: %w[return exchange])
        .order(completed_at: :desc)
        .limit(100)

      respond_to do |format|
        format.html
        format.csv do
          authorize_report!("pos.reports.export")
          send_data returns_csv(@transactions), filename: "pos-returns-#{Date.current}.csv", type: "text/csv"
        end
      end
    end
  end
end
