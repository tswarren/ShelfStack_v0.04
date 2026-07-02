# frozen_string_literal: true

module Purchasing
  module ReceiptPostingGuards
    module_function

    LEGACY_OPEN_ALLOCATION_STATUSES = DemandAllocations::InboundAvailability::LEGACY_OPEN_ALLOCATION_STATUSES

    def assert_no_mixed_claims!(receipt)
      receipt.receipt_lines.each do |receipt_line|
        po_line = receipt_line.purchase_order_line
        next if po_line.blank?

        legacy = po_line.purchase_order_line_allocations.where(status: LEGACY_OPEN_ALLOCATION_STATUSES).exists?
        v0047 = DemandAllocation.active_allocations.inbound_kind.where(purchase_order_line: po_line).exists?
        next unless legacy && v0047

        raise PostReceipt::PostingError,
              "Transitional mixed legacy and v0.04 inbound claims on PO line #{po_line.line_number}"
      end
    end
  end
end
