# frozen_string_literal: true

module Purchasing
  class PurchaseOrderLineDemandPlanSummary
    Row = Data.define(
      :demand_line,
      :quantity_planned,
      :coverage_kind,
      :fulfillment_route,
      :status
    )

    def self.for_purchase_order_line(purchase_order_line)
      new(purchase_order_line:).call
    end

    def initialize(purchase_order_line:)
      @purchase_order_line = purchase_order_line
    end

    def call
      purchase_order_line.purchase_order_line_demand_plans
                         .includes(:demand_line)
                         .order(:id)
                         .map do |plan|
        Row.new(
          demand_line: plan.demand_line,
          quantity_planned: plan.quantity_planned,
          coverage_kind: plan.coverage_kind,
          fulfillment_route: plan.fulfillment_route,
          status: plan.status
        )
      end
    end

    private

    attr_reader :purchase_order_line
  end
end
