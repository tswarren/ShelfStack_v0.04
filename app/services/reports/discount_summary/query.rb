# frozen_string_literal: true

module Reports
  module DiscountSummary
    Row = Data.define(:label, :application_count, :discount_cents, :row_type)
    Result = Data.define(:scope, :rows, :total_discount_cents, :metrics)

    class Query
      def self.call(scope:)
        new(scope: scope).call
      end

      def initialize(scope:)
        @scope = scope
      end

      def call
        applications = PosDiscountApplication.active_records
          .joins(:pos_transaction)
          .merge(scope.transactions)
          .includes(:discount_reason)

        grouped = applications.group(:discount_reason_id).sum(:applied_discount_cents)
        reasons = DiscountReason.where(id: grouped.keys).index_by(&:id)

        rows = grouped.map do |reason_id, cents|
          reason = reasons[reason_id]
          Row.new(
            label: reason&.name || "Unknown reason",
            application_count: applications.where(discount_reason_id: reason_id).count,
            discount_cents: cents.to_i,
            row_type: :detail
          )
        end.sort_by(&:label)

        total = grouped.values.sum(&:to_i)

        Result.new(
          scope: scope,
          rows: rows + [ Row.new(label: "Total discounts", application_count: applications.count, discount_cents: total, row_type: :total) ],
          total_discount_cents: total,
          metrics: [
            { label: "Total discounts", value_cents: total },
            { label: "Applications", value: applications.count },
            { label: "Line discounts", value: applications.where(scope: "line").count }
          ]
        )
      end

      private

      attr_reader :scope
    end
  end
end
