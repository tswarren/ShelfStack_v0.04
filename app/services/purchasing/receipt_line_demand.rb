# frozen_string_literal: true

module Purchasing
  class ReceiptLineDemand
    def self.customer_reserved_open(purchase_order_line)
      return 0 if purchase_order_line.blank?

      purchase_order_line.purchase_order_line_allocations.open_allocations.sum do |allocation|
        allocation.quantity_allocated - allocation.quantity_received
      end
    end
  end
end
