# frozen_string_literal: true

require "csv"

module Reports
  module SalesSummaryCsv
    extend ActiveSupport::Concern

    private

    def summary_csv_filename
      slug = @scope.label.parameterize
      "pos-sales-revenue-summary-#{slug}-#{Date.current}.csv"
    end

    def summary_csv(report)
      return "" if report.blank?

      CSV.generate do |csv|
        csv << [ "Sales & Revenue Summary", report.scope.label ]
        csv << []
        csv << [ "Metric", "Amount" ]
        csv << [ "Gross Sales", report.revenue_summary.gross_sales_cents ]
        csv << [ "Returns/Refunds", report.revenue_summary.refunds_cents ]
        csv << [ "Discounts Applied", report.revenue_summary.discounts_cents ]
        csv << [ "Net Sales", report.revenue_summary.net_sales_cents ]
        csv << [ "Taxes Collected", report.revenue_summary.taxes_cents ]
        csv << [ "Gift Card Redemptions", report.revenue_summary.gift_card_cents ]
        csv << [ "Gift Card Sales", report.revenue_summary.gift_card_sales_cents ]
        csv << [ "Total Sales", report.revenue_summary.total_sales_cents ]
        csv << []
        csv << [ "Clerk", "Transactions", "Sales", "Refunds", "Adjustments", "Discounts", "Net Sales", "Voids" ]
        report.by_clerk.each do |row|
          csv << clerk_csv_row(row)
        end
        csv << [
          "Total",
          report.revenue_summary.transaction_count,
          report.revenue_summary.sales_cents,
          report.revenue_summary.refunds_cents,
          report.revenue_summary.adjustments_cents,
          report.revenue_summary.discounts_cents,
          report.revenue_summary.net_sales_cents,
          report.revenue_summary.void_count
        ]
        csv << []
        csv << [ "Payment Type", "Amount" ]
        report.by_tender.each do |row|
          csv << [ row.label, row.amount_cents ]
        end
        csv << []
        csv << [ "Hour", "Transactions", "Sales", "Refunds", "Adjustments", "Discounts", "Net Sales", "Voids" ]
        report.by_hour.each do |row|
          csv << hourly_csv_row(row)
        end
        if report.drawer.available
          csv << []
          csv << [ "Drawer Reconciliation", "" ]
          csv << [ "Starting Bank", report.drawer.starting_bank_cents ]
          csv << [ "Cash Sales", report.drawer.cash_sales_cents ]
          csv << [ "Paid In", report.drawer.paid_in_cents ]
          csv << [ "Paid Out", report.drawer.paid_out_cents ]
          csv << [ "Expected Cash", report.drawer.expected_cash_cents ]
          csv << [ "Actual Cash", report.drawer.actual_cash_cents ]
          csv << [ "Variance", report.drawer.variance_cents ]
        end
      end
    end

    def clerk_csv_row(row)
      [
        row.clerk_name,
        row.metrics.transaction_count,
        row.metrics.sales_cents,
        row.metrics.refunds_cents,
        row.metrics.adjustments_cents,
        row.metrics.discounts_cents,
        row.metrics.net_sales_cents,
        row.metrics.void_count
      ]
    end

    def hourly_csv_row(row)
      [
        row.label,
        row.metrics.transaction_count,
        row.metrics.sales_cents,
        row.metrics.refunds_cents,
        row.metrics.adjustments_cents,
        row.metrics.discounts_cents,
        row.metrics.net_sales_cents,
        row.metrics.void_count
      ]
    end

    def sales_csv(transactions)
      CSV.generate do |csv|
        csv << %w[transaction_number completed_at type subtotal_cents tax_cents total_cents cashier]
        transactions.each do |transaction|
          csv << [
            transaction.transaction_number,
            transaction.completed_at,
            transaction.transaction_type,
            transaction.subtotal_cents,
            transaction.tax_cents,
            transaction.total_cents,
            transaction.cashier_user.username
          ]
        end
      end
    end

    def returns_csv(transactions)
      CSV.generate do |csv|
        csv << %w[transaction_number completed_at type total_cents cashier]
        transactions.each do |transaction|
          csv << [
            transaction.transaction_number,
            transaction.completed_at,
            transaction.transaction_type,
            transaction.total_cents,
            transaction.cashier_user.username
          ]
        end
      end
    end
  end
end
