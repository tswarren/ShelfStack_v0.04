# frozen_string_literal: true

module Reports
  module PurchasingSummary
    Result = Data.define(:scope_label, :po_counts, :receipt_totals, :metrics, :open_po_count)

    class Query
      def self.call(store:, start_date: nil, end_date: nil)
        new(store: store, start_date: start_date, end_date: end_date).call
      end

      def initialize(store:, start_date: nil, end_date: nil)
        @store = store
        @start_date = start_date
        @end_date = end_date
      end

      def call
        po_scope = PurchaseOrder.where(store: store).where.not(status: "draft")
        po_scope = po_scope.where(submitted_at: date_range) if date_range

        po_counts = po_scope.group(:status).count
        open_po_count = po_scope.where(status: PurchaseOrder::RECEIVABLE_PO_STATUSES).count

        receipt_scope = Receipt.where(store: store, status: "posted")
        receipt_scope = receipt_scope.where(posted_at: date_range) if date_range

        accepted_qty = ReceiptLine.joins(:receipt).merge(receipt_scope).sum(:quantity_accepted)
        rejected_qty = ReceiptLine.joins(:receipt).merge(receipt_scope).sum(:quantity_rejected)

        Result.new(
          scope_label: scope_label,
          po_counts: po_counts,
          receipt_totals: { accepted_qty: accepted_qty, rejected_qty: rejected_qty },
          open_po_count: open_po_count,
          metrics: [
            { label: "Purchase orders", value: po_scope.count },
            { label: "Open POs", value: open_po_count },
            { label: "Qty accepted", value: accepted_qty }
          ]
        )
      end

      private

      attr_reader :store, :start_date, :end_date

      def date_range
        return nil if start_date.blank? && end_date.blank?

        (start_date || 30.days.ago.to_date).beginning_of_day..(end_date || Date.current).end_of_day
      end

      def scope_label
        if start_date.present? || end_date.present?
          "#{start_date || '…'} – #{end_date || Date.current}"
        else
          "All dates"
        end
      end
    end
  end
end
