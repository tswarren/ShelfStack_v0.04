# frozen_string_literal: true

module Reports
  module CustomerRequests
    Row = Data.define(:label, :status, :status_class, :aging_days, :item_label, :variant_id, :request_path)
    Result = Data.define(:scope_label, :rows, :metrics, :empty?)

    STATUS_CLASSES = {
      "new" => "ss-status-badge--info",
      "awaiting_customer_response" => "ss-status-badge--warning",
      "ready_for_pickup" => "ss-status-badge--success",
      "completed" => "ss-status-badge--muted",
      "cancelled" => "ss-status-badge--muted"
    }.freeze

    class Query
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

        index_rows = ::CustomerRequests::IndexRowPresenter.build_collection(relation.limit(100), store: store)

        rows = index_rows.map do |row|
          variant = row.request.customer_request_lines.first&.product_variant
          Row.new(
            label: row.request_number,
            status: row.status.tr("_", " ").titleize,
            status_class: STATUS_CLASSES.fetch(row.status, "ss-status-badge--info"),
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
            { label: "Requests", value: rows.size },
            { label: "Ready for pickup", value: ::CustomerRequests::QueueScope.count(store: store, queue_key: "ready_for_pickup") },
            { label: "Awaiting response", value: ::CustomerRequests::QueueScope.count(store: store, queue_key: "awaiting_response") }
          ],
          empty?: rows.empty?
        )
      end

      private

      attr_reader :store
    end
  end
end
