# frozen_string_literal: true

module Orders
  class DemandPoBuilderPresenter
    def initialize(store:, demand_lines:, mode: "create_new")
      @store = store
      @demand_lines = demand_lines
      @mode = mode
      @plan = Purchasing::DemandCoveragePlanner.call(demand_lines: demand_lines, store: store)
    end

    attr_reader :store, :demand_lines, :mode, :plan

    def vendor_groups
      plan.vendor_plans.map do |vendor_plan|
        VendorGroup.new(
          vendor_plan: vendor_plan,
          draft_purchase_orders: draft_purchase_orders_for(vendor_plan.vendor),
          customer_planned: vendor_plan.line_plans.sum(&:customer_quantity),
          shelf_planned: vendor_plan.line_plans.sum(&:store_quantity)
        )
      end
    end

    def total_customer_planned
      plan.line_plans.sum(&:customer_quantity)
    end

    def total_shelf_planned
      plan.line_plans.sum(&:store_quantity)
    end

    VendorGroup = Data.define(:vendor_plan, :draft_purchase_orders, :customer_planned, :shelf_planned)

    private

    def draft_purchase_orders_for(vendor)
      PurchaseOrder.drafts.where(store: store, vendor: vendor).order(updated_at: :desc)
    end
  end
end
