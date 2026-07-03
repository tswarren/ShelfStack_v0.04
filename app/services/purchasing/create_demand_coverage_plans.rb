# frozen_string_literal: true

module Purchasing
  class CreateDemandCoveragePlans
    class CreateError < StandardError; end

    def self.call!(purchase_order:, actor:, line_plans:)
      new(purchase_order:, actor:, line_plans:).call!
    end

    def initialize(purchase_order:, actor:, line_plans:)
      @purchase_order = purchase_order
      @actor = actor
      @line_plans = Array(line_plans)
    end

    def call!
      raise CreateError, "Purchase order must be draft" unless purchase_order.draft?

      created = []
      PurchaseOrder.transaction do
        line_plans.each do |plan|
          po_line = purchase_order.purchase_order_lines.find_by!(product_variant_id: plan.product_variant.id)
          qty = plan_quantity_for(plan)
          next if qty <= 0

          idempotency_key = idempotency_key_for(purchase_order, po_line, plan.demand_line)
          existing = PurchaseOrderLineDemandPlan.find_by(store: purchase_order.store, idempotency_key: idempotency_key)
          if existing&.active?
            created << existing
            next
          end

          if existing.present?
            revive_plan!(existing, qty, plan, po_line)
            created << existing
            next
          end

          record = PurchaseOrderLineDemandPlan.create!(
            store: purchase_order.store,
            purchase_order: purchase_order,
            purchase_order_line: po_line,
            demand_line: plan.demand_line,
            product: plan.demand_line.product,
            product_variant: plan.product_variant,
            quantity_planned: qty,
            fulfillment_route: fulfillment_route_for(plan),
            coverage_kind: coverage_kind_for(plan),
            status: "planned",
            created_by_user: actor,
            idempotency_key: idempotency_key
          )
          audit_created!(record, qty)
          created << record
        end
      end

      created
    end

    private

    attr_reader :purchase_order, :actor, :line_plans

    def idempotency_key_for(purchase_order, po_line, demand_line)
      "po:#{purchase_order.id}:line:#{po_line.id}:demand:#{demand_line.id}"
    end

    def revive_plan!(existing, qty, plan, po_line)
      existing.update!(
        purchase_order_line: po_line,
        demand_line: plan.demand_line,
        product: plan.demand_line.product,
        product_variant: plan.product_variant,
        quantity_planned: qty,
        fulfillment_route: fulfillment_route_for(plan),
        coverage_kind: coverage_kind_for(plan),
        status: "planned",
        released_at: nil,
        released_by_user: nil,
        release_reason: nil,
        converted_at: nil,
        converted_by_user: nil,
        converted_to_demand_allocation_id: nil
      )
      audit_created!(existing, qty)
    end

    def audit_created!(record, qty)
      AuditEvents.record!(
        actor: actor,
        event_name: "purchase_order_line_demand_plan.created",
        auditable: record,
        details: {
          "purchase_order_id" => purchase_order.id,
          "demand_line_id" => record.demand_line_id,
          "quantity_planned" => qty,
          "coverage_kind" => record.coverage_kind,
          "fulfillment_route" => record.fulfillment_route
        }
      )
    end

    def plan_quantity_for(plan)
      plan.total_quantity
    end

    def coverage_kind_for(plan)
      if plan.customer_quantity.positive? && plan.store_quantity.positive?
        "other"
      elsif plan.customer_quantity.positive?
        "customer_fulfillment"
      elsif plan.store_quantity.positive?
        "shelf_replenishment"
      else
        "other"
      end
    end

    def fulfillment_route_for(plan)
      purchase_order.customer_direct? ? "vendor_direct_to_customer" : "inbound_to_store"
    end
  end
end
