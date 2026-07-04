# frozen_string_literal: true

module Orders
  class DemandPoBuilderController < BaseController
    before_action -> { authorize!("orders.purchase_orders.create") }

    def new
      load_demand_lines!
      return if performed?

      @presenter = DemandPoBuilderPresenter.new(
        store: orders_store,
        demand_lines: @demand_lines,
        mode: params[:mode].presence || "create_new"
      )
    end

    def create
      load_demand_lines!
      return if performed?

      purchase_orders = []
      plan = Purchasing::DemandCoveragePlanner.call(demand_lines: @demand_lines, store: orders_store)

      if plan.vendor_plans.empty?
        @presenter = DemandPoBuilderPresenter.new(
          store: orders_store,
          demand_lines: @demand_lines,
          mode: params[:mode].presence || "create_new"
        )
        flash.now[:alert] = "No eligible vendor could be resolved for the selected demand."
        render :new, status: :unprocessable_entity
        return
      end

      PurchaseOrder.transaction do
        plan.vendor_plans.each do |vendor_plan|
          demand_line_ids = vendor_plan.line_plans.map { |lp| lp.demand_line.id }
          group_params = vendor_group_params(vendor_plan.vendor.id)
          mode = group_params[:mode].presence || "create_new"

          purchase_order = if mode == "add_existing" && group_params[:purchase_order_id].present?
            po = PurchaseOrder.drafts.where(store: orders_store, vendor: vendor_plan.vendor)
                              .find(group_params[:purchase_order_id])
            Purchasing::AddDemandToPurchaseOrder.call!(
              purchase_order: po,
              created_by_user: current_user,
              demand_line_ids: demand_line_ids
            )
            po
          else
            Purchasing::BuildPurchaseOrderFromDemand.call!(
              store: orders_store,
              vendor: vendor_plan.vendor,
              created_by_user: current_user,
              demand_line_ids: demand_line_ids,
              notes: params[:notes]
            )
          end
          purchase_orders << purchase_order
        end
      end

      if purchase_orders.one?
        redirect_to orders_purchase_order_path(purchase_orders.first),
                    notice: "Draft PO ##{purchase_orders.first.id} updated with planned demand coverage."
      else
        redirect_to orders_purchase_orders_path,
                    notice: "Created/updated #{purchase_orders.size} draft purchase orders with planned coverage."
      end
    rescue Purchasing::BuildPurchaseOrderFromDemand::BuildError,
           Purchasing::AddDemandToPurchaseOrder::AddError,
           ActiveRecord::RecordNotFound => e
      @presenter = DemandPoBuilderPresenter.new(store: orders_store, demand_lines: @demand_lines)
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    private

    def load_demand_lines!
      ids = Array(params[:demand_line_ids]).map(&:to_i).uniq
      if ids.empty?
        redirect_to orders_buyer_workbench_path, alert: "Select at least one demand line."
        return
      end

      @demand_lines = DemandLine.where(store: orders_store, id: ids).includes(:product_variant, :customer)
      missing = ids - @demand_lines.pluck(:id)
      return if missing.empty?

      redirect_to orders_buyer_workbench_path, alert: "Some demand lines were not found."
    end

    def vendor_group_params(vendor_id)
      params.fetch(:vendor_groups, {}).fetch(vendor_id.to_s, {}).permit(:mode, :purchase_order_id)
    end
  end
end
