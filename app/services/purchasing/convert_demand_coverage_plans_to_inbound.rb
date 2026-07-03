# frozen_string_literal: true

module Purchasing
  class ConvertDemandCoveragePlansToInbound
    class ConversionError < StandardError; end

    def self.call!(purchase_order:, actor:)
      new(purchase_order:, actor:).call!
    end

    def initialize(purchase_order:, actor:)
      @purchase_order = purchase_order
      @actor = actor
    end

    def call!
      return [] if purchase_order.draft?
      return [] if purchase_order.customer_direct?

      converted = []
      PurchaseOrder.transaction do
        purchase_order.purchase_order_line_demand_plans.active_plans.find_each do |plan|
          next unless plan.inbound_to_store?

          inbound = DemandAllocations::InboundAvailability.new(purchase_order_line: plan.purchase_order_line)
          next unless inbound.eligible?

          qty = [ plan.quantity_planned, inbound.available_for ].min
          next if qty <= 0
          next if plan.converted_to_demand_allocation_id.present?

          allocation = DemandAllocations::AllocateInboundPurchaseOrder.call!(
            demand_line: plan.demand_line,
            actor: actor,
            purchase_order_line: plan.purchase_order_line,
            quantity: qty
          )

          plan.update!(
            status: "converted",
            converted_at: Time.current,
            converted_by_user: actor,
            converted_to_demand_allocation_id: allocation.id
          )

          AuditEvents.record!(
            actor: actor,
            event_name: "purchase_order_line_demand_plan.converted_to_inbound",
            auditable: plan,
            details: {
              "demand_allocation_id" => allocation.id,
              "quantity" => qty
            }
          )
          converted << allocation
        end
      end

      converted
    rescue DemandAllocations::AllocateInboundPurchaseOrder::AllocateError => e
      raise ConversionError, e.message
    end

    private

    attr_reader :purchase_order, :actor
  end
end
