# frozen_string_literal: true

module Reports
  module Shells
    class QueuePresenter
      Row = Data.define(:label, :status, :status_class, :aging_days, :variant_id, :item_label)

      def initialize(empty: false, status: nil)
        @empty = empty
        @status = status
      end

      def title
        "Customer Request Queue (Sample Shell)"
      end

      def scope_label
        filter = @status.present? ? "Status: #{@status.tr('_', ' ')}" : "All open statuses"
        "#{filter} · Created-at aging"
      end

      def metrics
        return [] if @empty

        [
          { label: "Open requests", value: "3" },
          { label: "Ready for pickup", value: "1" },
          { label: "Awaiting receiving", value: "1" }
        ]
      end

      def rows
        return [] if @empty

        [
          Row.new(
            label: "Special order — The Great Gatsby",
            status: "Ready for pickup",
            status_class: "status-active",
            aging_days: 2,
            variant_id: 101,
            item_label: "The Great Gatsby"
          ),
          Row.new(
            label: "Notify — Station Eleven",
            status: "Awaiting receiving",
            status_class: "status-partial",
            aging_days: 5,
            variant_id: 102,
            item_label: "Station Eleven"
          ),
          Row.new(
            label: "TBO — Indie title",
            status: "Open",
            status_class: "status-draft",
            aging_days: 1,
            variant_id: 103,
            item_label: "Indie title"
          )
        ]
      end

      def empty?
        @empty
      end
    end
  end
end
