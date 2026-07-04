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
      views = Receiving::ReceiptPostingMatchAdapter.call(receipt: receipt)
      return if views.empty?
      return unless po_backed_receipt?

      PurchaseOrder.transaction do
        views.each do |view|
          next if view.purchase_order_line.blank?

          po_line = view.purchase_order_line
          po_line.receiving_update = true
          po_line.quantity_received += view.quantity_accepted
          po_line.status = PoLineStatusDeriver.derive(po_line)
          po_line.save!
        end

        purchase_orders_for(receipt).each do |purchase_order|
          purchase_order.update!(status: header_status_for(purchase_order))
        end
      end
    end

    private

    attr_reader :receipt

    def po_backed_receipt?
      receipt.po_backed? || Receiving::ReceiptPostingMatchAdapter.call(receipt: receipt).any?
    end

    def purchase_orders_for(receipt)
      ids = Receiving::ReceiptPostingMatchAdapter.call(receipt: receipt)
                                                   .filter_map { |view| view.purchase_order_line&.purchase_order_id }
      ids << receipt.purchase_order_id if receipt.purchase_order_id.present?
      PurchaseOrder.where(id: ids.compact.uniq)
    end

    def header_status_for(purchase_order)
      lines = purchase_order.purchase_order_lines.reload
      return "received" if lines.all? { |line| line.status == "received" }
      return "partially_received" if lines.any? { |line| line.quantity_received.positive? }

      purchase_order.status
    end
  end
end
