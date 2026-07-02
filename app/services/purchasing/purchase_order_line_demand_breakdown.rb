# frozen_string_literal: true

module Purchasing
  class PurchaseOrderLineDemandBreakdown
    AllocationRow = Data.define(
      :allocation,
      :customer_name,
      :demand_number,
      :demand_line_id,
      :quantity_allocated,
      :quantity_open,
      :allocation_kind,
      :status
    )

    LineBreakdown = Data.define(
      :line,
      :demand_allocated_quantity,
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
      rows = allocation_rows_for(line)
      demand_allocated = rows.sum(&:quantity_open)

      LineBreakdown.new(
        line: line,
        demand_allocated_quantity: demand_allocated,
        stock_quantity: [ line.quantity_ordered - demand_allocated, 0 ].max,
        allocation_rows: rows
      )
    end

    def allocation_rows_for(line)
      DemandAllocation.active_allocations
                      .where(purchase_order_line: line)
                      .includes(demand_line: :customer)
                      .order(:allocated_at)
                      .map do |allocation|
        demand_line = allocation.demand_line

        AllocationRow.new(
          allocation: allocation,
          customer_name: demand_line.display_customer_name,
          demand_number: demand_line.demand_number,
          demand_line_id: demand_line.id,
          quantity_allocated: allocation.quantity_allocated,
          quantity_open: allocation.quantity_allocated,
          allocation_kind: allocation.allocation_kind,
          status: allocation.status
        )
      end
    end
  end
end
