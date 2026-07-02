# frozen_string_literal: true

module Purchasing
  class UpdatePoLineQuantities
    def self.call(receipt:)
      new(receipt:).call
    end

    def initialize(receipt:)
      @receipt = receipt
    end

    def call
      return unless receipt.po_backed?

      PurchaseOrder.transaction do
        receipt.receipt_lines.each do |receipt_line|
          next if receipt_line.purchase_order_line.blank?

          po_line = receipt_line.purchase_order_line
          po_line.receiving_update = true
          po_line.quantity_received += receipt_line.quantity_accepted
          po_line.status = line_status_for(po_line)
          po_line.save!
        end

        purchase_order = receipt.purchase_order
        purchase_order.update!(status: header_status_for(purchase_order)) if purchase_order
      end
    end

    private

    attr_reader :receipt

    def line_status_for(po_line)
      summary = Purchasing::PoLineQuantitySummary.for(po_line)

      return "closed_short" if po_line.quantity_closed_short.positive?
      return "received" if summary.open_to_receive_quantity.zero? && po_line.quantity_received.positive?
      return "partially_received" if po_line.quantity_received.positive?
      return "backordered" if summary.vendor_quantities_recorded? && po_line.quantity_backordered_by_vendor.positive?
      return "cancelled" if summary.vendor_quantities_recorded? && po_line.quantity_canceled_by_vendor >= po_line.quantity_ordered

      po_line.status
    end

    def header_status_for(purchase_order)
      lines = purchase_order.purchase_order_lines.reload
      return "received" if lines.all? { |line| line.status == "received" }
      return "partially_received" if lines.any? { |line| line.quantity_received.positive? }

      purchase_order.status
    end
  end
end
