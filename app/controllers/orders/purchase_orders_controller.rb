# frozen_string_literal: true

module Orders
  class PurchaseOrdersController < BaseController
    before_action :set_purchase_order, only: %i[show edit update submit cancel close receive]
    before_action -> { authorize!("orders.purchase_orders.view") }, only: %i[index show]
    before_action -> { authorize!("orders.purchase_orders.create") }, only: %i[new create edit update]
    before_action -> { authorize!("orders.purchase_orders.submit") }, only: :submit
    before_action -> { authorize!("orders.purchase_orders.cancel") }, only: :cancel
    before_action -> { authorize!("orders.purchase_orders.close") }, only: :close
    before_action -> { authorize!("orders.receipts.create") }, only: :receive

    def index
      @purchase_orders = PurchaseOrder
        .includes(:vendor, :submitted_by_user)
        .where(store: orders_store)
        .order(created_at: :desc)
    end

    def show
      @order_summary = Purchasing::PurchaseOrderSummary.call(@purchase_order)
      @document_hub = Purchasing::PurchaseOrderDocumentHub.call(@purchase_order)
      @sourcing_warnings = Purchasing::SourcingWarnings.for_purchase_order(@purchase_order)
      @show_presenter = Orders::PurchaseOrderShowPresenter.new(
        purchase_order: @purchase_order,
        document_hub: @document_hub,
        order_summary: @order_summary,
        sourcing_warnings: @sourcing_warnings,
        line_demand_breakdowns: Purchasing::PurchaseOrderLineDemandBreakdown.for(@purchase_order)
      )
      @audit_events = AuditEvent.for_auditable(@purchase_order).limit(50)
      @closable = Purchasing::ClosePurchaseOrder.new(
        purchase_order: @purchase_order,
        closed_by_user: current_user
      ).closable?
      @receivable = @purchase_order.receivable?
    end

    def new
      @purchase_order = PurchaseOrder.new(store: orders_store, status: "draft")
      build_initial_line
      load_form_collections
      @sourcing_warnings = []
    end

    def create
      @purchase_order = PurchaseOrder.new(purchase_order_params)
      @purchase_order.store = orders_store
      @purchase_order.status = "draft"

      assign_purchase_order_line_defaults(@purchase_order)

      if @purchase_order.save
        record_audit!("purchase_order.created", @purchase_order)
        redirect_to orders_purchase_order_path(@purchase_order), notice: "Draft purchase order created."
      else
        load_form_collections
        @sourcing_warnings = Purchasing::SourcingWarnings.for_purchase_order(@purchase_order)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      redirect_to orders_purchase_order_path(@purchase_order), alert: "Submitted purchase orders cannot be edited." unless @purchase_order.draft?
      load_form_collections
      @sourcing_warnings = Purchasing::SourcingWarnings.for_purchase_order(@purchase_order)
    end

    def update
      unless @purchase_order.draft?
        redirect_to orders_purchase_order_path(@purchase_order), alert: "Submitted purchase orders cannot be edited."
        return
      end

      @purchase_order.assign_attributes(purchase_order_params)
      assign_purchase_order_line_defaults(@purchase_order)

      if @purchase_order.save
        record_audit!("purchase_order.updated", @purchase_order)
        redirect_to orders_purchase_order_path(@purchase_order), notice: "Draft purchase order updated."
      else
        load_form_collections
        @sourcing_warnings = Purchasing::SourcingWarnings.for_purchase_order(@purchase_order)
        render :edit, status: :unprocessable_entity
      end
    end

    def submit
      Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: current_user)
      redirect_to orders_purchase_order_path(@purchase_order), notice: "Purchase order submitted."
    rescue Purchasing::SubmitPurchaseOrder::SubmitError => e
      redirect_to orders_purchase_order_path(@purchase_order), alert: e.message
    end

    def cancel
      unless @purchase_order.draft? || @purchase_order.status == "submitted"
        redirect_to orders_purchase_order_path(@purchase_order), alert: "This purchase order cannot be cancelled."
        return
      end

      @purchase_order.update!(status: "cancelled")
      record_audit!("purchase_order.cancelled", @purchase_order)
      redirect_to orders_purchase_orders_path, notice: "Purchase order cancelled."
    end

    def close
      Purchasing::ClosePurchaseOrder.call(purchase_order: @purchase_order, closed_by_user: current_user)
      redirect_to orders_purchase_order_path(@purchase_order), notice: "Purchase order closed."
    rescue Purchasing::ClosePurchaseOrder::CloseError => e
      redirect_to orders_purchase_order_path(@purchase_order), alert: e.message
    end

    def receive
      Purchasing::CustomerDirectPurchaseOrderGate.assert_receivable!(@purchase_order)
      receipt = Purchasing::BuildReceiptFromPurchaseOrder.call(
        purchase_order: @purchase_order,
        created_by_user: current_user
      )
      redirect_to edit_orders_receipt_path(receipt), notice: "Draft receipt created from purchase order."
    rescue Purchasing::BuildReceiptFromPurchaseOrder::BuildError => e
      redirect_to orders_purchase_order_path(@purchase_order), alert: e.message
    rescue Purchasing::CustomerDirectPurchaseOrderGate::GateError => e
      redirect_to orders_purchase_order_path(@purchase_order), alert: e.message
    end

    private

    def set_purchase_order
      relation = PurchaseOrder.where(store: orders_store)
      if action_name == "show"
        relation = relation.includes(
          :receipts,
          purchase_order_lines: [
            :product_variant,
            :demand_allocations,
            :purchase_order_line_demand_plans,
            { receipt_lines: [ :receipt, :receiving_discrepancies ] }
          ]
        )
      end
      @purchase_order = relation.find(params[:id])
    end

    def load_form_collections
      @vendors = Vendor.active_records.order(:name)
    end

    def assign_purchase_order_line_defaults(purchase_order)
      purchase_order.purchase_order_lines.each do |line|
        line.vendor = purchase_order.vendor if line.vendor.blank? && purchase_order.vendor.present?
        line.status ||= "open"
        line.quantity_received ||= 0
        Purchasing::LineEconomicsSync.apply!(line) if line.product_variant.present?
      end
    end

    def build_initial_line
      if params[:product_variant_id].present?
        variant = ProductVariant.active_records.find_by(id: params[:product_variant_id])
        if variant
          @purchase_order.purchase_order_lines.build(
            product_variant: variant,
            quantity_ordered: 1
          )
          return
        end
      end

      @purchase_order.purchase_order_lines.build
    end

    def purchase_order_params
      params.require(:purchase_order).permit(
        :vendor_id,
        :notes,
        purchase_order_lines_attributes: %i[
          id line_number product_variant_id product_variant_vendor_id quantity_ordered
          unit_list_price_cents supplier_discount_bps unit_cost_cents expected_retail_price_cents
          line_note manual_cost_override manual_price_override _destroy
        ]
      )
    end
  end
end
