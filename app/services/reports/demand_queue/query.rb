# frozen_string_literal: true

module Reports
  module DemandQueue
    Row = Data.define(:label, :status, :aging_days, :item_label, :variant_id, :demand_path)
    Result = Data.define(:scope_label, :rows, :metrics, :empty?, :truncated)

    class Query
      ROW_LIMIT = 100

      def self.call(store:, queue: nil, status: nil)
        new(store: store, queue: queue, status: status).call
      end

      def initialize(store:, queue: nil, status: nil)
        @store = store
        @queue = queue
        @status = status
      end

      def call
        relation = DemandLine.includes(:customer, :product_variant)
                             .where(store: store)
                             .order(created_at: :desc)

        relation = ::DemandLines::QueueScope.apply(relation, @queue, store: store) if @queue.present?
        relation = relation.where(status: @status) if @status.present?

        matching_count = relation.count
        demand_lines = relation.limit(ROW_LIMIT)

        rows = demand_lines.map do |demand_line|
          Row.new(
            label: demand_line.demand_number,
            status: demand_line.status,
            aging_days: (Date.current - demand_line.created_at.to_date).to_i,
            item_label: item_label_for(demand_line),
            variant_id: demand_line.product_variant_id,
            demand_path: Rails.application.routes.url_helpers.demand_demand_line_path(demand_line)
          )
        end

        Result.new(
          scope_label: @queue.present? ? CustomersHelper::DEMAND_QUEUE_LABELS.fetch(@queue, @queue.humanize) : "All demand",
          rows: rows,
          metrics: [
            { label: "Demand lines", value: matching_count },
            { label: "Ready for pickup", value: ::DemandLines::QueueScope.count(store: store, queue_key: "ready_for_pickup") },
            { label: "Awaiting response", value: ::DemandLines::QueueScope.count(store: store, queue_key: "awaiting_response") }
          ],
          empty?: rows.empty?,
          truncated: matching_count > ROW_LIMIT
        )
      end

      private

      attr_reader :store

      def item_label_for(demand_line)
        if demand_line.product_variant.present?
          demand_line.product_variant.name.presence || demand_line.product_variant.sku
        else
          demand_line.provisional_title.presence || demand_line.provisional_identifier.presence || "Unresolved"
        end
      end
    end
  end
end
