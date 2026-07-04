# frozen_string_literal: true

module Receiving
  module ReceiptPoLineMatchConstraints
    STORE_VENDOR_MISMATCH = "PO line must belong to the same store and vendor as the receipt"

    module_function

    def compatible?(receipt:, po_line:)
      purchase_order = po_line.purchase_order
      purchase_order.store_id == receipt.store_id &&
        purchase_order.vendor_id == receipt.vendor_id
    end

    def assert_compatible!(receipt:, po_line:, error_class: StandardError)
      return if compatible?(receipt:, po_line:)

      raise error_class, STORE_VENDOR_MISMATCH
    end

    def add_incompatibility_errors(receipt:, po_line:, errors:)
      purchase_order = po_line.purchase_order
      if purchase_order.store_id != receipt.store_id
        errors.add(:purchase_order, "must belong to the same store as the receipt")
      end
      if purchase_order.vendor_id != receipt.vendor_id
        errors.add(:purchase_order, "must belong to the same vendor as the receipt")
      end
    end
  end
end
