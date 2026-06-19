# frozen_string_literal: true

module Pos
  class SalesRegisterSummaryReport
    RevenueSummary = Data.define(
      :gross_sales_cents,
      :refunds_cents,
      :line_discount_cents,
      :order_discount_cents,
      :net_sales_cents,
      :taxes_cents,
      :total_sales_cents
    )

    TransactionMixRow = Data.define(:label, :count, :amount_cents, :units_sold)
    PaymentRow = Data.define(:label, :amount_cents)
    TaxRow = Data.define(:label, :tax_cents)
    BreakdownRow = Data.define(:label, :transaction_count, :units_sold, :metrics, :void_count)
    DrawerReconciliation = Data.define(
      :starting_bank_cents,
      :cash_sales_cents,
      :cash_refunds_cents,
      :paid_in_cents,
      :paid_out_cents,
      :expected_cash_cents,
      :actual_cash_cents,
      :variance_cents,
      :available
    )
    Exceptions = Data.define(
      :void_count,
      :void_cents,
      :no_receipt_return_count,
      :auth_override_count
    )

    Report = Data.define(
      :scope,
      :session,
      :revenue,
      :transaction_mix,
      :payments,
      :taxes,
      :drawer,
      :by_clerk,
      :by_hour,
      :exceptions,
      :totals,
      :breakdown_total
    )

    def self.call(scope:)
      new(scope).call
    end

    def initialize(scope)
      @scope = scope
    end

    def call
      raise ArgumentError, "Register summary requires a register session scope." unless scope.register_session?

      session = scope.register_session
      transactions = scope.transactions.to_a
      voids = scope.voids.includes(:pos_transaction).to_a
      voided_transaction_ids = voids.map(&:pos_transaction_id).to_set
      void_counts_by_cashier = voids.group_by { |pos_void| pos_void.pos_transaction.cashier_user_id }
        .transform_values(&:size)

      totals = aggregate(transactions)
      revenue = build_revenue(totals)
      transaction_mix = build_transaction_mix(transactions, voids, totals.units_sold)
      payments = build_payments(transactions)
      taxes = build_taxes(transactions)
      drawer = build_drawer(session)
      by_clerk = build_breakdown_rows(transactions, void_counts_by_cashier) { |user| user.display_name }
      by_hour = build_hourly_rows(transactions, voided_transaction_ids)
      exceptions = build_exceptions(voids, transactions)
      breakdown_total = BreakdownRow.new(
        label: "Total",
        transaction_count: transactions.size,
        units_sold: totals.units_sold,
        metrics: totals,
        void_count: exceptions.void_count
      )

      Report.new(
        scope: scope,
        session: session,
        revenue: revenue,
        transaction_mix: transaction_mix,
        payments: payments,
        taxes: taxes,
        drawer: drawer,
        by_clerk: by_clerk,
        by_hour: by_hour,
        exceptions: exceptions,
        totals: totals,
        breakdown_total: breakdown_total
      )
    end

    private

    attr_reader :scope

    def aggregate(transactions)
      ReportTransactionMetrics.combine(transactions.map { |transaction| ReportTransactionMetrics.from_transaction(transaction) })
    end

    def build_revenue(totals)
      RevenueSummary.new(
        gross_sales_cents: totals.sales_cents,
        refunds_cents: totals.refunds_cents,
        line_discount_cents: -totals.line_discount_cents,
        order_discount_cents: -totals.order_discount_cents,
        net_sales_cents: totals.net_sales_cents,
        taxes_cents: totals.taxes_cents,
        total_sales_cents: ReportTransactionMetrics.total_sales_cents(totals)
      )
    end

    def build_transaction_mix(transactions, voids, units_sold)
      grouped = transactions.group_by(&:transaction_type)

      [
        mix_row("Sales", grouped.fetch("sale", [])),
        mix_row("Returns", grouped.fetch("return", []), amount: :refunds),
        mix_row("Exchanges", grouped.fetch("exchange", [])),
        TransactionMixRow.new(
          label: "Voids",
          count: voids.size,
          amount_cents: voids.sum { |pos_void| pos_void.pos_transaction.total_cents.abs },
          units_sold: nil
        ),
        TransactionMixRow.new(label: "Units sold", count: nil, amount_cents: nil, units_sold: units_sold)
      ]
    end

    def mix_row(label, transactions, amount: :net)
      metrics = aggregate(transactions)
      amount_cents = case amount
                     when :refunds then metrics.refunds_cents
                     else metrics.net_sales_cents.abs
                     end

      TransactionMixRow.new(
        label: label,
        count: transactions.size,
        amount_cents: amount_cents,
        units_sold: nil
      )
    end

    def build_payments(transactions)
      cash_sales = 0
      cash_refunds = 0
      card_cents = 0
      check_cents = 0

      transactions.each do |transaction|
        transaction.pos_tenders.each do |tender|
          case tender.tender_type
          when "cash"
            if tender.amount_cents.negative?
              cash_refunds += tender.amount_cents
            else
              cash_sales += tender.amount_cents
            end
          when "card"
            card_cents += tender.amount_cents
          when "check"
            check_cents += tender.amount_cents
          end
        end
      end

      total_paid = cash_sales + cash_refunds + card_cents + check_cents
      [
        PaymentRow.new(label: "Cash sales", amount_cents: cash_sales),
        PaymentRow.new(label: "Cash refunds", amount_cents: cash_refunds),
        PaymentRow.new(label: "Card", amount_cents: card_cents),
        PaymentRow.new(label: "Check", amount_cents: check_cents),
        PaymentRow.new(label: "Total paid", amount_cents: total_paid)
      ]
    end

    def build_taxes(transactions)
      grouped = Hash.new(0)
      transactions.each do |transaction|
        transaction.pos_transaction_lines.each do |line|
          short_name = line.store_tax_rate_short_name_snapshot.presence || "Tax"
          identifier = line.tax_identifier_snapshot.presence || "—"
          label = "#{identifier} - #{short_name}"
          signed_tax = line.quantity.negative? ? -line.tax_cents : line.tax_cents
          grouped[label] += signed_tax
        end
      end

      rows = grouped.sort.map { |label, tax_cents| TaxRow.new(label: label, tax_cents: tax_cents) }
      rows << TaxRow.new(label: "Total tax", tax_cents: grouped.values.sum)
      rows
    end

    def build_drawer(session)
      summary = RegisterSessionSummary.for(session)
      actual = session.counted_closing_cash_cents
      variance = actual.present? ? actual - summary.expected_closing_cash_cents : nil

      DrawerReconciliation.new(
        starting_bank_cents: summary.opening_cash_cents,
        cash_sales_cents: summary.cash_sales_cents,
        cash_refunds_cents: summary.cash_refunds_cents,
        paid_in_cents: summary.paid_in_cents,
        paid_out_cents: summary.paid_out_cents,
        expected_cash_cents: summary.expected_closing_cash_cents,
        actual_cash_cents: actual,
        variance_cents: variance,
        available: true
      )
    end

    def build_breakdown_rows(transactions, void_counts_by_cashier)
      rows = transactions.group_by(&:cashier_user_id).map do |cashier_id, clerk_transactions|
        metrics = aggregate(clerk_transactions)
        BreakdownRow.new(
          label: yield(clerk_transactions.first.cashier_user),
          transaction_count: clerk_transactions.size,
          units_sold: metrics.units_sold,
          metrics: metrics,
          void_count: void_counts_by_cashier[cashier_id].to_i
        )
      end
      rows.sort_by { |row| row.label.downcase }
    end

    def build_hourly_rows(transactions, voided_transaction_ids)
      hourly_groups = transactions.group_by { |transaction| scope.local_time(transaction.completed_at).hour }
      rows = hourly_groups.sort.map do |hour, hour_transactions|
        metrics = aggregate(hour_transactions)
        BreakdownRow.new(
          label: ReportTransactionMetrics.compact_hour_label(hour),
          transaction_count: hour_transactions.size,
          units_sold: metrics.units_sold,
          metrics: metrics,
          void_count: hour_transactions.count { |transaction| voided_transaction_ids.include?(transaction.id) }
        )
      end

      totals = aggregate(transactions)
      rows << BreakdownRow.new(
        label: "Total",
        transaction_count: transactions.size,
        units_sold: totals.units_sold,
        metrics: totals,
        void_count: voided_transaction_ids.size
      )
      rows
    end

    def build_exceptions(voids, transactions)
      no_receipt_returns = transactions.sum do |transaction|
        ReportTransactionMetrics.from_transaction(transaction).no_receipt_return_lines
      end
      auth_overrides = PosAuthorization
        .where(store: scope.store, pos_register_session_id: scope.register_session.id)
        .where.not(granted_at: nil)
        .where(authorization_type: %w[discount_over_limit cash_refund_over_threshold])
        .count

      Exceptions.new(
        void_count: voids.size,
        void_cents: voids.sum { |pos_void| pos_void.pos_transaction.total_cents.abs },
        no_receipt_return_count: no_receipt_returns,
        auth_override_count: auth_overrides
      )
    end
  end
end
