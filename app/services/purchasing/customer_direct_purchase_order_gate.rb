# frozen_string_literal: true

module Purchasing
  module CustomerDirectPurchaseOrderGate
    module_function

    def assert_receivable!(purchase_order)
      return unless purchase_order.customer_direct?

      raise GateError, "Customer-direct purchase orders cannot be received at the store"
    end

    def assert_postable_receipt!(receipt)
      po_ids = receipt_po_ids(receipt)
      return if po_ids.empty?

      PurchaseOrder.where(id: po_ids, ship_to_type: "customer").find_each do |po|
        raise GateError, "Cannot post store receipt for customer-direct PO #{po.id}"
      end
    end

    def receipt_po_ids(receipt)
      ids = []
      ids << receipt.purchase_order_id if receipt.purchase_order_id.present?
      ids.concat(
        ReceiptLineMatch.confirmed_matches.where(receipt: receipt).pluck(:purchase_order_id)
      )
      ids.concat(receipt.receipt_lines.filter_map(&:purchase_order_line_id).map do |pol_id|
        PurchaseOrderLine.where(id: pol_id).pick(:purchase_order_id)
      end)
      ids.compact.uniq
    end

    class GateError < StandardError; end
  end
end
