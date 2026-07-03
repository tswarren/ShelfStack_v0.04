# frozen_string_literal: true

module Purchasing
  class DemandCoveragePlanner
    LinePlan = Data.define(
      :demand_line,
      :product_variant,
      :customer_quantity,
      :store_quantity,
      :total_quantity
    )

    VendorPlan = Data.define(
      :vendor,
      :line_plans,
      :total_quantity
    )

    Plan = Data.define(
      :vendor_plans,
      :line_plans
    )

    CUSTOMER_INTENTS = %w[hold notify special_order used_wanted research].freeze
    STORE_INTENTS = %w[manual_tbo buyer_replenishment].freeze

    def self.call(demand_lines:, vendor: nil, store:)
      new(demand_lines:, vendor:, store:).call
    end

    def initialize(demand_lines:, vendor: nil, store:)
      @demand_lines = Array(demand_lines)
      @vendor = vendor
      @store = store
    end

    def call
      line_plans = demand_lines.filter_map { |line| plan_line(line) }
      grouped = line_plans.group_by { |plan| resolve_vendor(plan.product_variant)&.id }

      vendor_plans = grouped.filter_map do |vendor_id, plans|
        next if vendor_id.blank?

        VendorPlan.new(
          vendor: Vendor.find(vendor_id),
          line_plans: plans,
          total_quantity: plans.sum(&:total_quantity)
        )
      end

      Plan.new(vendor_plans: vendor_plans, line_plans: line_plans)
    end

    private

    attr_reader :demand_lines, :vendor, :store

    def plan_line(demand_line)
      variant = demand_line.product_variant
      return nil if variant.blank?

      unallocated = DemandAllocations::AllocationQuantities.for_demand_line(demand_line)[:unallocated_quantity]
      return nil if unallocated <= 0

      customer_qty = CUSTOMER_INTENTS.include?(demand_line.capture_intent) ? unallocated : 0
      store_qty = STORE_INTENTS.include?(demand_line.capture_intent) ? unallocated : 0
      store_qty = unallocated if customer_qty.zero? && store_qty.zero?

      LinePlan.new(
        demand_line: demand_line,
        product_variant: variant,
        customer_quantity: customer_qty,
        store_quantity: store_qty,
        total_quantity: unallocated
      )
    end

    def resolve_vendor(variant)
      return vendor if vendor.present?

      suggestion = Sourcing::SuggestVendors.call!(variant: variant).first
      suggestion&.vendor
    end
  end
end
