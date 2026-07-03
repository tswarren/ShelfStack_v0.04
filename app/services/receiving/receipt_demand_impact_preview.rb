# frozen_string_literal: true

module Receiving
  class ReceiptDemandImpactPreview
    ImpactRow = Data.define(
      :demand_line,
      :quantity,
      :impact_kind
    )

    Preview = Data.define(
      :customer_ready_rows,
      :shelf_rows,
      :total_customer_ready,
      :total_shelf
    )

    def self.call(receipt:)
      new(receipt:).call
    end

    def initialize(receipt:)
      @receipt = receipt
    end

    def call
      customer_rows = []
      shelf_rows = []

      adapter_views = ReceiptPostingMatchAdapter.call(receipt: receipt)
      adapter_views.each do |view|
        next if view.purchase_order_line.blank?

        plans = view.purchase_order_line.purchase_order_line_demand_plans
                    .where(status: %w[planned partially_converted converted])
        inbound_allocs = DemandAllocation.active_allocations.inbound_kind
                                         .where(purchase_order_line: view.purchase_order_line)

        distribute_quantity(view.quantity_accepted, plans, inbound_allocs).each do |row|
          if row.impact_kind == "customer_ready"
            customer_rows << row
          else
            shelf_rows << row
          end
        end
      end

      Preview.new(
        customer_ready_rows: customer_rows,
        shelf_rows: shelf_rows,
        total_customer_ready: customer_rows.sum(&:quantity),
        total_shelf: shelf_rows.sum(&:quantity)
      )
    end

    private

    attr_reader :receipt

    def distribute_quantity(qty, plans, inbound_allocs)
      rows = []
      remaining = qty

      inbound_allocs.order(:allocated_at).each do |alloc|
        break if remaining.zero?

        take = [ remaining, alloc.quantity_allocated ].min
        kind = customer_demand?(alloc.demand_line) ? "customer_ready" : "shelf"
        rows << ImpactRow.new(demand_line: alloc.demand_line, quantity: take, impact_kind: kind)
        remaining -= take
      end

      if remaining.positive? && plans.any?
        kind = plans.any? { |p| p.coverage_kind == "customer_fulfillment" } ? "customer_ready" : "shelf"
        rows << ImpactRow.new(demand_line: plans.first.demand_line, quantity: remaining, impact_kind: kind)
      elsif remaining.positive?
        rows << ImpactRow.new(demand_line: nil, quantity: remaining, impact_kind: "shelf")
      end

      rows
    end

    def customer_demand?(demand_line)
      return false if demand_line.blank?

      Purchasing::DemandCoveragePlanner::CUSTOMER_INTENTS.include?(demand_line.capture_intent)
    end
  end
end
