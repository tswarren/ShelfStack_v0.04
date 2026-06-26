# frozen_string_literal: true

module Reports
  module TaxCollected
    Row = Data.define(
      :label,
      :taxable_sales_cents,
      :normal_tax_cents,
      :tax_cents,
      :exempt_overridden_cents,
      :row_type
    )
    Result = Data.define(:scope, :rows, :total_tax_cents, :metrics)

    GROUP_KEYS = %i[
      tax_category_id
      store_tax_rate_id
      applied_tax_source
      normal_tax_category_id
      normal_store_tax_rate_id
    ].freeze

    class Query
      def self.call(scope:)
        new(scope: scope).call
      end

      def initialize(scope:)
        @scope = scope
      end

      def call
        lines = PosTransactionLine.joins(:pos_transaction).merge(scope.transactions)
        aggregates = aggregate_lines(lines)
        labels = build_labels(aggregates.keys)

        rows = aggregates.map do |key, totals|
          exempt_overridden = [ totals[:normal_tax_cents] - totals[:tax_cents], 0 ].max
          Row.new(
            label: labels.fetch(key),
            taxable_sales_cents: totals[:taxable_sales_cents],
            normal_tax_cents: totals[:normal_tax_cents],
            tax_cents: totals[:tax_cents],
            exempt_overridden_cents: exempt_overridden,
            row_type: :detail
          )
        end.sort_by(&:label)

        total_tax = rows.sum(&:tax_cents)

        Result.new(
          scope: scope,
          rows: rows + [
            Row.new(
              label: "Total tax collected",
              taxable_sales_cents: nil,
              normal_tax_cents: rows.sum(&:normal_tax_cents),
              tax_cents: total_tax,
              exempt_overridden_cents: rows.sum(&:exempt_overridden_cents),
              row_type: :total
            )
          ],
          total_tax_cents: total_tax,
          metrics: [
            { label: "Tax collected", value_cents: total_tax },
            { label: "Taxable lines", value: lines.where("pos_transaction_lines.tax_cents > 0").count },
            { label: "Exempt/overridden lines", value: lines.where("pos_transaction_lines.normal_tax_cents > pos_transaction_lines.tax_cents").count }
          ]
        )
      end

      private

      attr_reader :scope

      def aggregate_lines(lines)
        lines.pluck(*GROUP_KEYS, :extended_price_cents, :normal_tax_cents, :tax_cents).each_with_object({}) do |values, groups|
          key_values = values.first(GROUP_KEYS.size)
          extended_price_cents, normal_tax_cents, tax_cents = values.last(3)
          key = GROUP_KEYS.zip(key_values).to_h
          groups[key] ||= { taxable_sales_cents: 0, normal_tax_cents: 0, tax_cents: 0 }
          groups[key][:taxable_sales_cents] += extended_price_cents.to_i
          groups[key][:normal_tax_cents] += normal_tax_cents.to_i
          groups[key][:tax_cents] += tax_cents.to_i
        end
      end

      def build_labels(keys)
        tax_category_ids = keys.flat_map { |key| [ key[:tax_category_id], key[:normal_tax_category_id] ] }.compact.uniq
        store_tax_rate_ids = keys.flat_map { |key| [ key[:store_tax_rate_id], key[:normal_store_tax_rate_id] ] }.compact.uniq

        tax_categories = TaxCategory.where(id: tax_category_ids).index_by(&:id)
        store_tax_rates = StoreTaxRate.where(id: store_tax_rate_ids).index_by(&:id)

        keys.index_with do |key|
          row_label(key, tax_categories: tax_categories, store_tax_rates: store_tax_rates)
        end
      end

      def row_label(key, tax_categories:, store_tax_rates:)
        category = tax_categories[key[:tax_category_id]] || tax_categories[key[:normal_tax_category_id]]
        rate = store_tax_rates[key[:store_tax_rate_id]] || store_tax_rates[key[:normal_store_tax_rate_id]]

        parts = []
        parts << (category&.name || "Uncategorized")
        parts << format_rate(rate) if rate.present?
        parts << source_label(key[:applied_tax_source])
        parts.compact.join(" · ")
      end

      def format_rate(rate)
        format("%.2f%%", rate.tax_rate_bps / 100.0)
      end

      def source_label(source)
        return "Unknown source" if source.blank?

        source.tr("_", " ").titleize
      end
    end
  end
end
