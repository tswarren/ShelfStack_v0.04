# frozen_string_literal: true

module Purchasing
  class ReceiptLineDemand
    def self.customer_reserved_open(purchase_order_line)
      return 0 if purchase_order_line.blank?

      DemandAllocation.active_allocations
                      .inbound_kind
                      .where(purchase_order_line: purchase_order_line)
                      .sum(:quantity_allocated)
    end
  end
end
