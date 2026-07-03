# frozen_string_literal: true

module Purchasing
  class PurchaseOrderDocumentHub
    ReceiveProgress = Data.define(:ordered, :received, :open)
    ManualTboDemandLink = Data.define(:demand_line, :line_count)
    ReceiptSummary = Data.define(:receipt, :line_count, :accepted_quantity)
    DiscrepancyRow = Data.define(:receipt, :purchase_order_line, :sku, :discrepancy_type, :quantity_delta)
    ReceiptLineActivity = Data.define(:receipt, :quantity_expected, :quantity_received, :quantity_accepted)
    LineActivity = Data.define(:purchase_order_line, :open_quantity, :receipt_lines)

    Result = Data.define(
      :receive_progress,
      :purchase_requests,
      :receipts,
      :discrepancies,
      :line_activity
    )

    def self.call(purchase_order)
      new(purchase_order).call
    end

    def initialize(purchase_order)
      @purchase_order = purchase_order
    end

    def call
      Result.new(
        receive_progress: receive_progress,
        purchase_requests: purchase_requests,
        receipts: receipt_summaries,
        discrepancies: discrepancies,
        line_activity: line_activity
      )
    end

    private

    attr_reader :purchase_order

    def receive_progress
      ordered = 0
      received = 0

      purchase_order.purchase_order_lines.each do |line|
        ordered += line.quantity_ordered
        received += line.quantity_received
      end

      ReceiveProgress.new(ordered:, received:, open: [ ordered - received, 0 ].max)
    end

    def purchase_requests
      []
    end

    def legacy_request_line_ids(purchase_order)
      AuditEvent
        .where(auditable: purchase_order, event_name: "purchase_order.created")
        .order(created_at: :asc)
        .flat_map { |event| Array(event.event_details["from_purchase_request_lines"]) }
        .map(&:to_i)
        .uniq
    end

    def receipt_summaries
      purchase_order.receipts.sort_by(&:created_at).reverse.map do |receipt|
        lines = receipt.receipt_lines.to_a
        ReceiptSummary.new(
          receipt: receipt,
          line_count: lines.size,
          accepted_quantity: lines.sum(&:quantity_accepted)
        )
      end
    end

    def discrepancies
      rows = []

      purchase_order.receipts.select(&:posted?).each do |receipt|
        receipt.receipt_lines.each do |receipt_line|
          receipt_line.receiving_discrepancies.each do |discrepancy|
            po_line = receipt_line.purchase_order_line
            sku = po_line&.variant_sku_snapshot.presence || receipt_line.product_variant.sku
            rows << DiscrepancyRow.new(
              receipt: receipt,
              purchase_order_line: po_line,
              sku: sku,
              discrepancy_type: discrepancy.discrepancy_type,
              quantity_delta: discrepancy.quantity_delta
            )
          end
        end
      end

      rows
    end

    def line_activity
      purchase_order.purchase_order_lines.map do |line|
        receipt_lines = line.receipt_lines.sort_by { |receipt_line| receipt_line.receipt.created_at }.map do |receipt_line|
          ReceiptLineActivity.new(
            receipt: receipt_line.receipt,
            quantity_expected: receipt_line.quantity_expected,
            quantity_received: receipt_line.quantity_received,
            quantity_accepted: receipt_line.quantity_accepted
          )
        end

        LineActivity.new(
          purchase_order_line: line,
          open_quantity: purchase_order.open_quantity_for_line(line),
          receipt_lines: receipt_lines
        )
      end
    end
  end
end
