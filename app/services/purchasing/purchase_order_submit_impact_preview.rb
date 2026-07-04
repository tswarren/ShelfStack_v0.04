# frozen_string_literal: true

module Purchasing
  class PurchaseOrderSubmitImpactPreview
    Preview = Data.define(
      :total_planned_copies,
      :customer_inbound_copies,
      :shelf_inbound_copies,
      :remaining_planned_copies,
      :message
    )

    def self.call(purchase_order:)
      new(purchase_order:).call
    end

    def initialize(purchase_order:)
      @purchase_order = purchase_order
    end

    def call
      return nil unless purchase_order.draft?
      return nil if purchase_order.customer_direct?

      customer_inbound = 0
      shelf_inbound = 0
      total_planned = 0

      purchase_order.purchase_order_line_demand_plans.active_plans.includes(:purchase_order_line).find_each do |plan|
        next unless plan.inbound_to_store?

        total_planned += plan.quantity_planned
        inbound = DemandAllocations::InboundAvailability.new(purchase_order_line: plan.purchase_order_line)
        qty = [ plan.quantity_planned, inbound.available_for ].min
        next if qty <= 0

        if plan.coverage_kind == "customer_fulfillment"
          customer_inbound += qty
        else
          shelf_inbound += qty
        end
      end

      return nil if total_planned.zero?

      converting = customer_inbound + shelf_inbound
      remaining = [ total_planned - converting, 0 ].max
      message = build_message(customer_inbound, shelf_inbound, remaining)

      Preview.new(
        total_planned_copies: total_planned,
        customer_inbound_copies: customer_inbound,
        shelf_inbound_copies: shelf_inbound,
        remaining_planned_copies: remaining,
        message: message
      )
    end

    private

    attr_reader :purchase_order

    def build_message(customer_inbound, shelf_inbound, remaining)
      parts = []
      if customer_inbound.positive?
        parts << "On submit, inbound allocations will be created for #{customer_inbound} customer #{'copy'.pluralize(customer_inbound)}"
      end
      if shelf_inbound.positive? || remaining.positive?
        shelf_total = shelf_inbound + remaining
        parts << "#{shelf_total} #{'copy'.pluralize(shelf_total)} will remain planned for shelf or unassigned stock" if shelf_total.positive?
      end
      parts.join(". ")
    end
  end
end
