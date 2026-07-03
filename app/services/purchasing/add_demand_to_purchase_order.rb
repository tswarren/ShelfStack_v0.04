# frozen_string_literal: true

module Purchasing
  class AddDemandToPurchaseOrder
    class AddError < StandardError; end

    def self.call!(purchase_order:, created_by_user:, demand_line_ids:)
      new(purchase_order:, created_by_user:, demand_line_ids:).call!
    end

    def initialize(purchase_order:, created_by_user:, demand_line_ids:)
      @purchase_order = purchase_order
      @created_by_user = created_by_user
      @demand_line_ids = Array(demand_line_ids).map(&:to_i).uniq
    end

    def call!
      raise AddError, "Purchase order must be draft" unless purchase_order.draft?

      demand_lines = DemandLine.where(id: demand_line_ids, store: purchase_order.store).includes(:product_variant)
      raise AddError, "Select at least one demand line" if demand_lines.empty?

      plan = DemandCoveragePlanner.call(
        demand_lines: demand_lines,
        vendor: purchase_order.vendor,
        store: purchase_order.store
      )
      vendor_plan = plan.vendor_plans.find { |vp| vp.vendor.id == purchase_order.vendor_id }
      raise AddError, "Selected demand does not match this vendor" if vendor_plan.blank?

      PurchaseOrder.transaction do
        vendor_plan.line_plans.group_by(&:product_variant).each do |variant, plans|
          qty = plans.sum(&:total_quantity)
          existing = purchase_order.purchase_order_lines.find_by(product_variant_id: variant.id, status: "open")
          if existing
            existing.update!(quantity_ordered: existing.quantity_ordered + qty)
          else
            defaults = LinePriceDefaults.resolve(variant: variant, vendor: purchase_order.vendor)
            purchase_order.purchase_order_lines.create!(
              vendor: purchase_order.vendor,
              product_variant: variant,
              quantity_ordered: qty,
              quantity_received: 0,
              status: "open",
              unit_list_price_cents: defaults.unit_list_price_cents,
              supplier_discount_bps: defaults.supplier_discount_bps,
              unit_cost_cents: defaults.unit_cost_cents
            )
          end
        end

        AuditEvents.record!(
          actor: created_by_user,
          event_name: "purchase_order.demand_added",
          auditable: purchase_order,
          details: {
            "demand_line_ids" => demand_lines.map(&:id),
            "demand_numbers" => demand_lines.map(&:demand_number)
          }
        )

        CreateDemandCoveragePlans.call!(
          purchase_order: purchase_order,
          actor: created_by_user,
          line_plans: vendor_plan.line_plans
        )
      end

      purchase_order.reload
    rescue ActiveRecord::RecordInvalid => e
      raise AddError, e.record.errors.full_messages.to_sentence
    end

    private

    attr_reader :purchase_order, :created_by_user, :demand_line_ids
  end
end
