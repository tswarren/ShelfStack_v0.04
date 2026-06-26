# frozen_string_literal: true

module Reports
  module TaxCollected
    RateRow = Data.define(
      :label,
      :sales_cents,
      :returns_cents,
      :net_taxable_sales_cents,
      :tax_collected_cents,
      :tax_refunded_cents,
      :net_tax_cents,
      :row_type
    )

    AdjustmentRow = Data.define(
      :label,
      :line_count,
      :affected_sales_cents,
      :normal_tax_cents,
      :actual_tax_cents,
      :difference_cents,
      :row_type
    )

    Result = Data.define(
      :scope,
      :summary_metrics,
      :rate_rows,
      :adjustment_rows,
      :total_tax_cents
    )

    RATE_GROUP_KEYS = %i[
      tax_category_id
      store_tax_rate_id
      tax_rate_bps
      tax_identifier_snapshot
      store_tax_rate_short_name_snapshot
    ].freeze

    SOURCE_LABELS = {
      "normal" => "Standard taxable sale",
      "transaction_exemption" => "Tax-exempt transaction",
      "line_override" => "Manual line tax override",
      "non_taxable" => "Non-taxable item",
      "sourced_return" => "Return/refund of prior sale"
    }.freeze

    class Query
      def self.call(scope:)
        new(scope: scope).call
      end

      def initialize(scope:)
        @scope = scope
      end

      def call
        lines = PosTransactionLine.joins(:pos_transaction).merge(scope.transactions)
        line_values = lines.pluck(
          *RATE_GROUP_KEYS,
          :applied_tax_source,
          :extended_price_cents,
          :normal_tax_cents,
          :tax_cents
        )

        rate_aggregates = aggregate_rate_rows(line_values)
        adjustment_aggregates = aggregate_adjustment_rows(line_values)
        tax_categories = load_tax_categories(rate_aggregates.keys)

        rate_rows = build_rate_rows(rate_aggregates, tax_categories: tax_categories)
        adjustment_rows = build_adjustment_rows(adjustment_aggregates)
        summary_metrics = build_summary_metrics(line_values, rate_rows, adjustment_rows)

        Result.new(
          scope: scope,
          summary_metrics: summary_metrics,
          rate_rows: rate_rows,
          adjustment_rows: adjustment_rows,
          total_tax_cents: rate_rows.find { |row| row.row_type == :total }&.net_tax_cents.to_i
        )
      end

      private

      attr_reader :scope

      def aggregate_rate_rows(line_values)
        line_values.each_with_object({}) do |values, groups|
          key_values = values.first(RATE_GROUP_KEYS.size)
          extended_price_cents, tax_cents = values.values_at(-3, -1)
          key = RATE_GROUP_KEYS.zip(key_values).to_h
          groups[key] ||= {
            sales_cents: 0,
            returns_cents: 0,
            tax_collected_cents: 0,
            tax_refunded_cents: 0
          }

          if extended_price_cents.to_i >= 0
            groups[key][:sales_cents] += extended_price_cents.to_i
          else
            groups[key][:returns_cents] += extended_price_cents.to_i
          end

          if tax_cents.to_i >= 0
            groups[key][:tax_collected_cents] += tax_cents.to_i
          else
            groups[key][:tax_refunded_cents] += tax_cents.to_i
          end
        end
      end

      def aggregate_adjustment_rows(line_values)
        line_values.each_with_object({}) do |values, groups|
          applied_tax_source = values[-4]
          extended_price_cents, normal_tax_cents, tax_cents = values.values_at(-3, -2, -1)
          next unless adjustment_line?(applied_tax_source, normal_tax_cents, tax_cents)

          source_key = applied_tax_source.presence || "__needs_review__"
          groups[source_key] ||= {
            line_count: 0,
            affected_sales_cents: 0,
            normal_tax_cents: 0,
            actual_tax_cents: 0
          }
          groups[source_key][:line_count] += 1
          groups[source_key][:affected_sales_cents] += extended_price_cents.to_i
          groups[source_key][:normal_tax_cents] += normal_tax_cents.to_i
          groups[source_key][:actual_tax_cents] += tax_cents.to_i
        end
      end

      def adjustment_line?(applied_tax_source, normal_tax_cents, tax_cents)
        return true if applied_tax_source.blank?
        return true if applied_tax_source != "normal"
        return true if normal_tax_cents.to_i != tax_cents.to_i

        false
      end

      def build_rate_rows(rate_aggregates, tax_categories:)
        rows = rate_aggregates.map do |key, totals|
          RateRow.new(
            label: rate_row_label(key, tax_categories: tax_categories),
            sales_cents: totals[:sales_cents],
            returns_cents: totals[:returns_cents],
            net_taxable_sales_cents: totals[:sales_cents] + totals[:returns_cents],
            tax_collected_cents: totals[:tax_collected_cents],
            tax_refunded_cents: totals[:tax_refunded_cents],
            net_tax_cents: totals[:tax_collected_cents] + totals[:tax_refunded_cents],
            row_type: :detail
          )
        end.sort_by(&:label)

        rows + [ rate_total_row(rows) ]
      end

      def rate_total_row(rows)
        RateRow.new(
          label: "Total",
          sales_cents: rows.sum(&:sales_cents),
          returns_cents: rows.sum(&:returns_cents),
          net_taxable_sales_cents: rows.sum(&:net_taxable_sales_cents),
          tax_collected_cents: rows.sum(&:tax_collected_cents),
          tax_refunded_cents: rows.sum(&:tax_refunded_cents),
          net_tax_cents: rows.sum(&:net_tax_cents),
          row_type: :total
        )
      end

      def build_adjustment_rows(adjustment_aggregates)
        rows = adjustment_aggregates.map do |source_key, totals|
          normal_tax = totals[:normal_tax_cents]
          actual_tax = totals[:actual_tax_cents]
          AdjustmentRow.new(
            label: adjustment_label(source_key),
            line_count: totals[:line_count],
            affected_sales_cents: totals[:affected_sales_cents],
            normal_tax_cents: normal_tax,
            actual_tax_cents: actual_tax,
            difference_cents: adjustment_difference(normal_tax, actual_tax),
            row_type: :detail
          )
        end.sort_by(&:label)

        return rows if rows.empty?

        rows + [
          AdjustmentRow.new(
            label: "Total",
            line_count: rows.sum(&:line_count),
            affected_sales_cents: rows.sum(&:affected_sales_cents),
            normal_tax_cents: rows.sum(&:normal_tax_cents),
            actual_tax_cents: rows.sum(&:actual_tax_cents),
            difference_cents: rows.filter_map(&:difference_cents).sum,
            row_type: :total
          )
        ]
      end

      def build_summary_metrics(line_values, rate_rows, adjustment_rows)
        total_row = rate_rows.find { |row| row.row_type == :total }
        review_line_count = line_values.count { |values| values[-4].blank? }
        exempt_overridden_cents = adjustment_rows
          .select { |row| row.row_type == :detail }
          .filter_map(&:difference_cents)
          .sum

        [
          { label: "Net taxable sales", value_cents: total_row&.net_taxable_sales_cents.to_i },
          { label: "Tax collected", value_cents: total_row&.tax_collected_cents.to_i },
          { label: "Tax refunded", value_cents: total_row&.tax_refunded_cents.to_i },
          { label: "Net tax collected", value_cents: total_row&.net_tax_cents.to_i, class: "ss-money" },
          { label: "Exempt / overridden tax", value_cents: exempt_overridden_cents },
          { label: "Lines needing review", value: review_line_count }
        ]
      end

      def load_tax_categories(rate_keys)
        tax_category_ids = rate_keys.map { |key| key[:tax_category_id] }.compact.uniq
        TaxCategory.where(id: tax_category_ids).index_by(&:id)
      end

      def rate_row_label(key, tax_categories:)
        parts = []
        parts << key[:store_tax_rate_short_name_snapshot] if key[:store_tax_rate_short_name_snapshot].present?
        parts << format_bps(key[:tax_rate_bps]) if key[:tax_rate_bps].present?
        category = tax_categories[key[:tax_category_id]]
        parts << category.name if category.present?
        parts << "Uncategorized" if parts.empty?
        parts.join(" · ")
      end

      def format_bps(bps)
        format("%.2f%%", bps.to_i / 100.0)
      end

      def adjustment_label(source_key)
        return "Needs review" if source_key == "__needs_review__"

        SOURCE_LABELS.fetch(source_key, source_key.tr("_", " ").titleize)
      end

      def adjustment_difference(normal_tax_cents, actual_tax_cents)
        return nil if normal_tax_cents.to_i == actual_tax_cents.to_i

        normal_tax_cents.to_i - actual_tax_cents.to_i
      end
    end
  end
end
