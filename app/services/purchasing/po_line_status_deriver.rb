# frozen_string_literal: true

module Purchasing
  class PoLineStatusDeriver
    def self.derive(purchase_order_line)
      new(purchase_order_line).derive
    end

    def initialize(purchase_order_line)
      @purchase_order_line = purchase_order_line
    end

    def derive
      line = purchase_order_line
      summary = PoLineQuantitySummary.for(line)

      return "closed_short" if line.quantity_closed_short.positive?
      if summary.vendor_quantities_recorded? && line.quantity_canceled_by_vendor.to_i >= line.quantity_ordered.to_i
        return "cancelled"
      end
      if line.quantity_received.positive? && summary.open_to_receive_quantity.positive?
        return "partially_received"
      end
      if summary.vendor_quantities_recorded? && line.quantity_backordered_by_vendor.positive?
        return "backordered"
      end
      if line.quantity_received.positive? && summary.open_to_receive_quantity.zero?
        return "received"
      end

      line.status
    end

    private

    attr_reader :purchase_order_line
  end
end
