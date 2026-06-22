# frozen_string_literal: true

module Purchasing
  class PurchaseOrderLineDemandBreakdown
    AllocationRow = Data.define(
      :allocation,
      :customer_name,
      :request_number,
      :request_id,
      :special_order_id,
      :quantity_allocated,
      :quantity_received,
      :quantity_open,
      :status
    )

    LineBreakdown = Data.define(
      :line,
      :customer_allocated_quantity,
      :internal_tbo_quantity,
      :stock_quantity,
      :allocation_rows
    )

    def self.for(purchase_order)
      new(purchase_order).call
    end

    def initialize(purchase_order)
      @purchase_order = purchase_order
    end

    def call
      purchase_order.purchase_order_lines.map { |line| breakdown_for(line) }
    end

    def for_line(line)
      breakdown_for(line)
    end

    private

    attr_reader :purchase_order

    def breakdown_for(line)
      customer_allocated = open_customer_allocated_quantity(line)
      tbo_qty = internal_tbo_quantity(line)
      stock_qty = [ line.quantity_ordered - customer_allocated - tbo_qty, 0 ].max

      LineBreakdown.new(
        line: line,
        customer_allocated_quantity: customer_allocated,
        internal_tbo_quantity: tbo_qty,
        stock_quantity: stock_qty,
        allocation_rows: allocation_rows_for(line)
      )
    end

    def open_customer_allocated_quantity(line)
      line.purchase_order_line_allocations.sum do |allocation|
        next 0 unless %w[active partially_received].include?(allocation.status)

        allocation.quantity_allocated - allocation.quantity_received
      end
    end

    def internal_tbo_quantity(line)
      return 0 if line.purchase_request_line_id.blank?

      line.quantity_ordered
    end

    def allocation_rows_for(line)
      line.purchase_order_line_allocations.order(:created_at).filter_map do |allocation|
        next if allocation.status == "cancelled"

        special_order = allocation.special_order
        request_line = allocation.customer_request_line
        request = request_line&.customer_request
        customer = special_order&.customer

        AllocationRow.new(
          allocation: allocation,
          customer_name: customer&.display_name || "—",
          request_number: request&.request_number,
          request_id: request&.id,
          special_order_id: special_order&.id,
          quantity_allocated: allocation.quantity_allocated,
          quantity_received: allocation.quantity_received,
          quantity_open: [ allocation.quantity_allocated - allocation.quantity_received, 0 ].max,
          status: allocation.status
        )
      end
    end
  end
end
