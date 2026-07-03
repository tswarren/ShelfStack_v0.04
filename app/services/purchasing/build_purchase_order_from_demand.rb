# frozen_string_literal: true

module Purchasing
  class BuildPurchaseOrderFromDemand
    class BuildError < StandardError; end

    def self.call!(store:, vendor:, created_by_user:, demand_line_ids:, notes: nil)
      new(store:, vendor:, created_by_user:, demand_line_ids:, notes:).call!
    end

    def initialize(store:, vendor:, created_by_user:, demand_line_ids:, notes: nil)
      @store = store
      @vendor = vendor
      @created_by_user = created_by_user
      @demand_line_ids = Array(demand_line_ids).map(&:to_i).uniq
      @notes = notes
    end

    def call!
      demand_lines = DemandLine.where(id: demand_line_ids, store: store).includes(:product_variant)
      raise BuildError, "Select at least one demand line" if demand_lines.empty?

      plan = DemandCoveragePlanner.call(demand_lines: demand_lines, vendor: vendor, store: store)
      vendor_plan = plan.vendor_plans.find { |vp| vp.vendor.id == vendor.id }
      raise BuildError, "No eligible lines for this vendor" if vendor_plan.blank?

      manual_lines = aggregate_manual_lines(vendor_plan.line_plans)

      purchase_order = BuildPurchaseOrder.call(
        store: store,
        vendor: vendor,
        created_by_user: created_by_user,
        manual_lines: manual_lines,
        notes: notes
      )

      record_demand_links!(purchase_order, demand_lines)
      CreateDemandCoveragePlans.call!(
        purchase_order: purchase_order,
        actor: created_by_user,
        line_plans: vendor_plan.line_plans
      )

      purchase_order
    rescue BuildPurchaseOrder::BuildError => e
      raise BuildError, e.message
    rescue ActiveRecord::RecordInvalid => e
      raise BuildError, e.record.errors.full_messages.to_sentence
    end

    private

    attr_reader :store, :vendor, :created_by_user, :demand_line_ids, :notes

    def aggregate_manual_lines(line_plans)
      line_plans.group_by(&:product_variant).map do |variant, plans|
        qty = plans.sum(&:total_quantity)
        defaults = LinePriceDefaults.resolve(variant: variant, vendor: vendor)

        {
          product_variant_id: variant.id,
          quantity_ordered: qty,
          unit_list_price_cents: defaults.unit_list_price_cents,
          supplier_discount_bps: defaults.supplier_discount_bps,
          unit_cost_cents: defaults.unit_cost_cents
        }
      end
    end

    def record_demand_links!(purchase_order, demand_lines)
      AuditEvents.record!(
        actor: created_by_user,
        event_name: "purchase_order.created_from_demand",
        auditable: purchase_order,
        details: {
          "demand_line_ids" => demand_lines.map(&:id),
          "demand_numbers" => demand_lines.map(&:demand_number),
          "status" => purchase_order.status,
          "planned_coverage" => purchase_order.draft?
        }
      )
    end
  end
end
