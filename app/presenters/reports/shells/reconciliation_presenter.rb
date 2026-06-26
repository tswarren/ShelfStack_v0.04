# frozen_string_literal: true

module Reports
  module Shells
    class ReconciliationPresenter
      Row = Data.define(:label, :amount_cents, :row_type)

      def initialize(start_date: nil, end_date: nil)
        @start_date = start_date
        @end_date = end_date
      end

      def title
        "Tax Collected (Sample Shell)"
      end

      def scope_label
        parts = [ "Sample store · Business date basis" ]
        parts << " #{@start_date} – #{@end_date}" if @start_date.present? && @end_date.present?
        parts.join
      end

      def metrics
        [
          { label: "Net sales", value_cents: 1_245_000 },
          { label: "Tax collected", value_cents: 78_125 },
          { label: "Transactions", value: "42" }
        ]
      end

      def rows
        [
          Row.new(label: "Books — taxable 6%", amount_cents: 52_000, row_type: :detail),
          Row.new(label: "General merchandise — taxable 6%", amount_cents: 26_125, row_type: :detail),
          Row.new(label: "Taxable subtotal", amount_cents: 78_125, row_type: :subtotal),
          Row.new(label: "Total tax collected", amount_cents: 78_125, row_type: :total)
        ]
      end
    end
  end
end
