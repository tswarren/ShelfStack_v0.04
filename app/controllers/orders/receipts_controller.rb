# frozen_string_literal: true

module Orders
  class ReceiptsController < BaseController
    before_action :set_receipt, only: %i[show edit update post cancel]
    before_action -> { authorize!("orders.receipts.view") }, only: %i[index show]
    before_action -> { authorize!("orders.receipts.create") }, only: %i[new create edit update]
    before_action -> { authorize!("orders.receipts.post") }, only: :post
    before_action -> { authorize!("orders.receipts.cancel") }, only: :cancel

    def index
      @receipts = Receipt
        .includes(:vendor, :purchase_order)
        .where(store: orders_store)
        .order(created_at: :desc)
    end

    def show
      @document_hub = Purchasing::ReceiptDocumentHub.call(@receipt)
      @show_presenter = Orders::ReceiptShowPresenter.new(
        receipt: @receipt,
        document_hub: @document_hub
      )
      @receipt_line_matches = @receipt.receipt_line_matches.includes(:receipt_line, :purchase_order_line, :purchase_order).order(:id)
      @audit_events = AuditEvent.for_auditable(@receipt).limit(50)
    end

    def new
      if params[:receiving_mode] == "vendor_shipment"
        @receipt = Receiving::CreateVendorShipmentReceipt.call!(
          store: orders_store,
          vendor: Vendor.find(params[:vendor_id]),
          created_by_user: current_user,
          attrs: {
            vendor_shipment_reference: params[:vendor_shipment_reference],
            tracking_number: params[:tracking_number]
          }
        )
        record_audit!("receipt.created", @receipt)
        redirect_to edit_orders_receipt_path(@receipt), notice: "Vendor shipment receipt created."
        return
      end

      @receipt = Receipt.new(
        store: orders_store,
        receipt_type: params[:receipt_type].presence || "direct",
        status: "draft",
        origin_method: "manual",
        receiving_mode: params[:receiving_mode].presence || "direct",
        vendor_shipment_destination: "store"
      )
      build_initial_line
      load_form_collections
    end

    def create
      @receipt = Receipt.new(receipt_params)
      @receipt.store = orders_store
      @receipt.status = "draft"

      if @receipt.save
        record_audit!("receipt.created", @receipt)
        redirect_to orders_receipt_path(@receipt), notice: "Draft receipt created."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      redirect_to orders_receipt_path(@receipt), alert: "Posted receipts cannot be edited." unless @receipt.draft?
      load_form_collections
      load_allocation_preview!
    end

    def update
      unless @receipt.draft?
        redirect_to orders_receipt_path(@receipt), alert: "Posted receipts cannot be edited."
        return
      end

      if @receipt.update(receipt_params)
        record_audit!("receipt.updated", @receipt)
        redirect_to orders_receipt_path(@receipt), notice: "Draft receipt updated."
      else
        load_form_collections
        load_allocation_preview!
        render :edit, status: :unprocessable_entity
      end
    end

    def post
      Purchasing::PostReceipt.call(receipt: @receipt, posted_by_user: current_user)
      @receipt.reload
      document_hub = Purchasing::ReceiptDocumentHub.call(@receipt)
      presenter = Orders::ReceiptShowPresenter.new(receipt: @receipt, document_hub: document_hub)
      redirect_to orders_receipt_path(@receipt), notice: presenter.post_confirmation_message
    rescue Purchasing::PostReceipt::PostingError => e
      redirect_to orders_receipt_path(@receipt), alert: e.message
    end

    def cancel
      unless @receipt.draft?
        redirect_to orders_receipt_path(@receipt), alert: "Only draft receipts can be cancelled."
        return
      end

      @receipt.update!(status: "cancelled")
      record_audit!("receipt.cancelled", @receipt)
      redirect_to orders_receipts_path, notice: "Receipt cancelled."
    end

    private

    def set_receipt
      relation = Receipt.where(store: orders_store)
      if action_name == "show"
        relation = relation.includes(
          :purchase_order,
          :inventory_posting,
          receipt_lines: [
            :product_variant,
            :purchase_order_line,
            :receiving_discrepancies,
            { purchase_order_line: :demand_allocations }
          ],
          receipt_line_matches: [ :receipt_line, :purchase_order_line, :purchase_order ]
        )
      elsif %w[edit new].include?(action_name)
        relation = relation.includes(
          receipt_lines: {
            purchase_order_line: :demand_allocations
          }
        )
      end
      @receipt = relation.find(params[:id])
    end

    def load_form_collections
      @vendors = Vendor.active_records.order(:name)
      @purchase_orders = PurchaseOrder.where(store: orders_store).where.not(status: %w[cancelled closed]).order(created_at: :desc)
      @receipt_type_options = Receipt::RECEIPT_TYPES
    end

    def build_initial_line
      if params[:product_variant_id].present?
        variant = ProductVariant.active_records.find_by(id: params[:product_variant_id])
        if variant
          @receipt.receipt_lines.build(
            product_variant: variant,
            quantity_expected: 0,
            quantity_received: 0,
            quantity_accepted: 0,
            quantity_rejected: 0
          )
          return
        end
      end

      @receipt.receipt_lines.build
    end

    def load_allocation_preview!
      return unless @receipt.draft? && @receipt.po_backed?

      document_hub = Purchasing::ReceiptDocumentHub.call(@receipt)
      @allocation_preview = Orders::ReceiptShowPresenter.new(receipt: @receipt, document_hub: document_hub)
    end

    def receipt_params
      params.require(:receipt).permit(
        :vendor_id,
        :purchase_order_id,
        :receipt_type,
        :origin_method,
        :receiving_mode,
        :vendor_shipment_destination,
        :vendor_shipment_reference,
        :vendor_packing_slip_number,
        :vendor_invoice_number,
        :tracking_number,
        :received_at,
        receipt_lines_attributes: %i[
          id line_number product_variant_id purchase_order_line_id
          quantity_expected quantity_received quantity_accepted quantity_rejected exception_reason
          unit_list_price_cents supplier_discount_bps unit_cost_cents _destroy
        ]
      )
    end
  end
end
