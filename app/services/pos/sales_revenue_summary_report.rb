# frozen_string_literal: true

module Pos
  class SalesRevenueSummaryReport
    Metrics = Data.define(
      :sales_cents,
      :refunds_cents,
      :adjustments_cents,
      :discounts_cents,
      :net_sales_cents,
      :taxes_cents,
      :gift_card_cents,
      :transaction_count,
      :void_count
    ) do
      def self.zero
        new(
          sales_cents: 0,
          refunds_cents: 0,
          adjustments_cents: 0,
          discounts_cents: 0,
          net_sales_cents: 0,
          taxes_cents: 0,
          gift_card_cents: 0,
          transaction_count: 0,
          void_count: 0
        )
      end

      def +(other)
        Metrics.new(
          sales_cents: sales_cents + other.sales_cents,
          refunds_cents: refunds_cents + other.refunds_cents,
          adjustments_cents: adjustments_cents + other.adjustments_cents,
          discounts_cents: discounts_cents + other.discounts_cents,
          net_sales_cents: net_sales_cents + other.net_sales_cents,
          taxes_cents: taxes_cents + other.taxes_cents,
          gift_card_cents: gift_card_cents + other.gift_card_cents,
          transaction_count: transaction_count + other.transaction_count,
          void_count: void_count + other.void_count
        )
      end

      def with_void_count(count)
        Metrics.new(
          sales_cents: sales_cents,
          refunds_cents: refunds_cents,
          adjustments_cents: adjustments_cents,
          discounts_cents: discounts_cents,
          net_sales_cents: net_sales_cents,
          taxes_cents: taxes_cents,
          gift_card_cents: gift_card_cents,
          transaction_count: transaction_count,
          void_count: count
        )
      end

      def gross_sales_cents
        sales_cents
      end

      def total_sales_cents
        net_sales_cents + taxes_cents
      end
    end

    ClerkRow = Data.define(:clerk_name, :metrics)
    HourlyRow = Data.define(:hour, :label, :metrics)
    TenderRow = Data.define(:tender_type, :label, :amount_cents)
    DrawerReconciliation = Data.define(
      :starting_bank_cents,
      :cash_sales_cents,
      :paid_in_cents,
      :paid_out_cents,
      :expected_cash_cents,
      :actual_cash_cents,
      :variance_cents,
      :available
    )

    Report = Data.define(
      :scope,
      :revenue_summary,
      :by_clerk,
      :by_hour,
      :by_tender,
      :drawer
    )

    TENDER_LABELS = {
      "cash" => "Cash",
      "card" => "Credit/Debit Card",
      "check" => "Checks",
      "gift_card" => "Gift Cards",
      "store_credit" => "Store Credit"
    }.freeze

    TENDER_ORDER = %w[cash card check gift_card store_credit].freeze

    def self.call(scope:)
      new(scope).call
    end

    def initialize(scope)
      @scope = scope
    end

    def call
      transactions = scope.transactions.to_a
      voids = scope.voids.includes(:pos_transaction).to_a
      void_counts_by_cashier = voids.group_by { |pos_void| pos_void.pos_transaction.cashier_user_id }
        .transform_values(&:size)

      revenue_summary = aggregate_transactions(transactions).with_void_count(voids.size)
      by_clerk = build_clerk_rows(transactions, void_counts_by_cashier)
      by_hour = build_hourly_rows(transactions, voids)
      by_tender = build_tender_rows(transactions)
      drawer = build_drawer_reconciliation

      Report.new(
        scope: scope,
        revenue_summary: revenue_summary,
        by_clerk: by_clerk,
        by_hour: by_hour,
        by_tender: by_tender,
        drawer: drawer
      )
    end

    private

    attr_reader :scope

    def aggregate_transactions(transactions)
      transactions.reduce(Metrics.zero) { |total, transaction| total + transaction_metrics(transaction) }
    end

    def transaction_metrics(transaction)
      metrics = ReportTransactionMetrics.from_transaction(transaction)
      gift_card_cents = transaction.pos_tenders.select { |tender| tender.tender_type == "gift_card" }.sum(&:amount_cents)

      Metrics.new(
        sales_cents: metrics.sales_cents,
        refunds_cents: metrics.refunds_cents,
        adjustments_cents: transaction.rounding_cents.to_i,
        discounts_cents: ReportTransactionMetrics.total_discounts_cents(metrics),
        net_sales_cents: metrics.net_sales_cents,
        taxes_cents: metrics.taxes_cents,
        gift_card_cents: gift_card_cents,
        transaction_count: 1,
        void_count: 0
      )
    end

    def build_clerk_rows(transactions, void_counts_by_cashier)
      transactions.group_by(&:cashier_user_id).map do |cashier_id, clerk_transactions|
        metrics = aggregate_transactions(clerk_transactions)
          .with_void_count(void_counts_by_cashier[cashier_id].to_i)
        ClerkRow.new(
          clerk_name: clerk_transactions.first.cashier_user.display_name,
          metrics: metrics
        )
      end.sort_by { |row| row.clerk_name.downcase }
    end

    def build_hourly_rows(transactions, voids)
      transaction_groups = ReportTransactionMetrics.group_transactions_by_completion_hour(transactions, scope)
      void_groups = ReportTransactionMetrics.group_voids_by_voided_hour(voids, scope)
      hours = ReportTransactionMetrics.active_hours(transactions: transactions, voids: voids, scope: scope)

      rows = hours.map do |hour|
        hour_transactions = transaction_groups[hour] || []
        hour_voids = void_groups[hour] || []
        metrics = aggregate_transactions(hour_transactions).with_void_count(hour_voids.size)
        HourlyRow.new(hour: hour, label: hour_label(hour), metrics: metrics)
      end

      totals = aggregate_transactions(transactions).with_void_count(voids.size)
      rows << HourlyRow.new(hour: nil, label: "Total", metrics: totals)
      rows
    end

    def build_tender_rows(transactions)
      totals = Hash.new(0)
      card_by_brand = Hash.new(0)

      transactions.each do |transaction|
        transaction.pos_tenders.settlement_rows.each do |tender|
          totals[tender.tender_type] += tender.amount_cents
          if tender.tender_type == "card"
            brand = tender.card_brand.presence || "other"
            card_by_brand[brand] += tender.amount_cents
          end
        end
      end

      rows = []
      TENDER_ORDER.each do |tender_type|
        if tender_type == "card"
          card_by_brand.sort.each do |brand, amount_cents|
            rows << TenderRow.new(
              tender_type: "card",
              label: "Card — #{brand.humanize}",
              amount_cents: amount_cents
            )
          end
        else
          rows << TenderRow.new(
            tender_type: tender_type,
            label: TENDER_LABELS.fetch(tender_type),
            amount_cents: totals[tender_type]
          )
        end
      end

      rows << TenderRow.new(
        tender_type: "total",
        label: "Total Payments",
        amount_cents: totals.values.sum
      )
      rows
    end

    def build_drawer_reconciliation
      unless scope.register_session?
        return DrawerReconciliation.new(
          starting_bank_cents: 0,
          cash_sales_cents: 0,
          paid_in_cents: 0,
          paid_out_cents: 0,
          expected_cash_cents: 0,
          actual_cash_cents: nil,
          variance_cents: nil,
          available: false
        )
      end

      session = scope.register_session
      summary = RegisterSessionSummary.for(session)
      actual = session.counted_closing_cash_cents
      variance = actual.present? ? actual - summary.expected_closing_cash_cents : nil

      DrawerReconciliation.new(
        starting_bank_cents: summary.opening_cash_cents,
        cash_sales_cents: summary.cash_sales_cents,
        paid_in_cents: summary.paid_in_cents,
        paid_out_cents: summary.paid_out_cents,
        expected_cash_cents: summary.expected_closing_cash_cents,
        actual_cash_cents: actual,
        variance_cents: variance,
        available: true
      )
    end

    def hour_label(hour)
      start_time = Time.zone.local(2000, 1, 1, hour, 0)
      end_time = start_time + 1.hour
      "#{format_hour(start_time)} - #{format_hour(end_time)}"
    end

    def format_hour(time)
      time.strftime("%-l:%M %p").sub(":00", "").strip.downcase.gsub(" ", "")
        .gsub("am", "am").gsub("pm", "pm")
    end
  end
end
