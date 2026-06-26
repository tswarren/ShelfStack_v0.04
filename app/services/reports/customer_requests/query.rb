# frozen_string_literal: true

module Reports
  module CustomerRequests
    Row = Data.define(:label, :status, :aging_days, :item_label, :variant_id, :request_path)
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
        relation = CustomerRequest.includes(:customer, customer_request_lines: :product_variant)
          .where(store: store)
          .order(created_at: :desc)

        relation = ::CustomerRequests::QueueScope.apply(relation, @queue, store: store) if @queue.present?
        relation = relation.where(status: @status) if @status.present?

        matching_count = relation.count
        index_rows = ::CustomerRequests::IndexRowPresenter.build_collection(relation.limit(ROW_LIMIT), store: store)

        rows = index_rows.map do |row|
          variant = row.request.customer_request_lines.first&.product_variant
          Row.new(
            label: row.request_number,
            status: row.status,
            aging_days: (Date.current - row.request.created_at.to_date).to_i,
            item_label: row.primary_item.presence || "Unresolved",
            variant_id: variant&.id,
            request_path: row.request_path
          )
        end

        Result.new(
          scope_label: @queue.present? ? @queue.tr("_", " ").titleize : "All requests",
          rows: rows,
          metrics: [
            { label: "Requests", value: matching_count },
            { label: "Ready for pickup", value: ::CustomerRequests::QueueScope.count(store: store, queue_key: "ready_for_pickup") },
            { label: "Awaiting response", value: ::CustomerRequests::QueueScope.count(store: store, queue_key: "awaiting_response") }
          ],
          empty?: rows.empty?,
          truncated: matching_count > ROW_LIMIT
        )
      end

      private

      attr_reader :store
    end
  end
end
