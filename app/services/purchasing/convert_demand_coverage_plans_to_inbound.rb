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

          allocation = convert_plan!(plan)
          converted << allocation if allocation.present?
        end
      end

      converted
    rescue DemandAllocations::AllocateInboundPurchaseOrder::AllocateError => e
      raise ConversionError, e.message
    end

    private

    attr_reader :purchase_order, :actor

    def convert_plan!(plan)
      inbound = DemandAllocations::InboundAvailability.new(purchase_order_line: plan.purchase_order_line)
      return nil unless inbound.eligible?

      qty = [ plan.quantity_planned, inbound.available_for ].min
      return nil if qty <= 0

      allocation = DemandAllocations::AllocateInboundPurchaseOrder.call!(
        demand_line: plan.demand_line,
        actor: actor,
        purchase_order_line: plan.purchase_order_line,
        quantity: qty
      )

      if qty >= plan.quantity_planned
        mark_converted!(plan, qty, allocation)
      else
        split_partial_conversion!(plan, qty, allocation)
      end

      allocation
    end

    def mark_converted!(plan, qty, allocation)
      plan.update!(
        status: "converted",
        quantity_planned: qty,
        converted_at: Time.current,
        converted_by_user: actor,
        converted_to_demand_allocation_id: allocation.id
      )

      audit_conversion!(plan, allocation, qty)
    end

    def split_partial_conversion!(plan, qty, allocation)
      remainder = plan.quantity_planned - qty
      idempotency_key = plan.idempotency_key

      plan.update!(
        status: "converted",
        quantity_planned: qty,
        converted_at: Time.current,
        converted_by_user: actor,
        converted_to_demand_allocation_id: allocation.id
      )
      audit_conversion!(plan, allocation, qty, partial: true)

      return if remainder <= 0

      remainder_plan = PurchaseOrderLineDemandPlan.new(
        store: plan.store,
        purchase_order: plan.purchase_order,
        purchase_order_line: plan.purchase_order_line,
        demand_line: plan.demand_line,
        product: plan.product,
        product_variant: plan.product_variant,
        quantity_planned: remainder,
        fulfillment_route: plan.fulfillment_route,
        coverage_kind: plan.coverage_kind,
        status: "planned",
        created_by_user: actor,
        idempotency_key: idempotency_key,
        internal_split: true
      )
      remainder_plan.save!

      AuditEvents.record!(
        actor: actor,
        event_name: "purchase_order_line_demand_plan.created",
        auditable: remainder_plan,
        details: {
          "purchase_order_id" => purchase_order.id,
          "demand_line_id" => remainder_plan.demand_line_id,
          "quantity_planned" => remainder,
          "coverage_kind" => remainder_plan.coverage_kind,
          "fulfillment_route" => remainder_plan.fulfillment_route,
          "split_from_plan_id" => plan.id
        }
      )
    end

    def audit_conversion!(plan, allocation, qty, partial: false)
      AuditEvents.record!(
        actor: actor,
        event_name: "purchase_order_line_demand_plan.converted_to_inbound",
        auditable: plan,
        details: {
          "demand_allocation_id" => allocation.id,
          "quantity" => qty,
          "partial" => partial
        }
      )
    end
  end
end
