# frozen_string_literal: true

module Reports
  module TaxCollected
    Row = Data.define(:label, :taxable_sales_cents, :tax_cents, :row_type)
    Result = Data.define(:scope, :rows, :total_tax_cents, :metrics)

    class Query
      def self.call(scope:)
        new(scope: scope).call
      end

      def initialize(scope:)
        @scope = scope
      end

      def call
        lines = PosTransactionLine.joins(:pos_transaction).merge(scope.transactions)

        grouped_tax = lines.group(:applied_tax_source).sum(:tax_cents)
        grouped_taxable = lines.group(:applied_tax_source).sum(:extended_price_cents)

        rows = grouped_tax.map do |source, tax_cents|
          Row.new(
            label: source_label(source),
            taxable_sales_cents: grouped_taxable[source].to_i,
            tax_cents: tax_cents.to_i,
            row_type: :detail
          )
        end.sort_by(&:label)

        total_tax = grouped_tax.values.sum(&:to_i)

        Result.new(
          scope: scope,
          rows: rows + [ Row.new(label: "Total tax collected", taxable_sales_cents: nil, tax_cents: total_tax, row_type: :total) ],
          total_tax_cents: total_tax,
          metrics: [
            { label: "Tax collected", value_cents: total_tax },
            { label: "Taxable lines", value: lines.where("pos_transaction_lines.tax_cents > 0").count },
            { label: "Exempt lines", value: lines.where(applied_tax_source: "transaction_exemption").count }
          ]
        )
      end

      private

      attr_reader :scope

      def source_label(source)
        return "Unknown" if source.blank?

        source.tr("_", " ").titleize
      end
    end
  end
end
