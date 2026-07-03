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

    PlanRow = Data.define(
      :plan,
      :customer_name,
      :demand_number,
      :demand_line_id,
      :quantity_planned,
      :coverage_kind,
      :fulfillment_route,
      :status
    )

    LineBreakdown = Data.define(
      :line,
      :demand_allocated_quantity,
      :stock_quantity,
      :allocation_rows,
      :plan_rows,
      :coverage_mode
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
      if purchase_order.draft?
        planned_breakdown(line)
      else
        allocation_breakdown(line)
      end
    end

    def planned_breakdown(line)
      rows = plan_rows_for(line)
      customer_qty = rows.select { |row| row.coverage_kind == "customer_fulfillment" }.sum(&:quantity_planned)
      shelf_planned = rows.select { |row| row.coverage_kind == "shelf_replenishment" }.sum(&:quantity_planned)
      other_planned = rows.reject { |row| %w[customer_fulfillment shelf_replenishment].include?(row.coverage_kind) }.sum(&:quantity_planned)
      total_planned = customer_qty + shelf_planned + other_planned
      unassigned = [ line.quantity_ordered - total_planned, 0 ].max

      LineBreakdown.new(
        line: line,
        demand_allocated_quantity: customer_qty,
        stock_quantity: shelf_planned + unassigned,
        allocation_rows: [],
        plan_rows: rows,
        coverage_mode: :planned
      )
    end

    def allocation_breakdown(line)
      rows = allocation_rows_for(line)
      demand_allocated = rows.sum(&:quantity_open)

      LineBreakdown.new(
        line: line,
        demand_allocated_quantity: demand_allocated,
        stock_quantity: [ line.quantity_ordered - demand_allocated, 0 ].max,
        allocation_rows: rows,
        plan_rows: [],
        coverage_mode: :allocated
      )
    end

    def plan_rows_for(line)
      line.purchase_order_line_demand_plans
          .active_plans
          .includes(demand_line: :customer)
          .order(:id)
          .map do |plan|
        demand_line = plan.demand_line
        PlanRow.new(
          plan: plan,
          customer_name: demand_line.display_customer_name,
          demand_number: demand_line.demand_number,
          demand_line_id: demand_line.id,
          quantity_planned: plan.quantity_planned,
          coverage_kind: plan.coverage_kind,
          fulfillment_route: plan.fulfillment_route,
          status: plan.status
        )
      end
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
