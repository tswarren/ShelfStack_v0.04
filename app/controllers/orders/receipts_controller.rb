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
      @post_result = Orders::ReceiptPostResultPresenter.new(receipt: @receipt, document_hub: @document_hub) if @receipt.posted?
      @receipt_line_matches = @receipt.receipt_line_matches.includes(:receipt_line, :purchase_order_line, :purchase_order).order(:id)
      @audit_events = AuditEvent.for_auditable(@receipt).limit(50)
    end

    def new
      if params[:receiving_mode] == "vendor_shipment"
        @vendors = Vendor.active_records.order(:name)
        @purchase_orders = PurchaseOrder.where(store: orders_store, status: PurchaseOrder::RECEIVABLE_PO_STATUSES)
                                          .order(created_at: :desc)
        @vendor_shipment = OpenStruct.new(
          vendor_id: params[:vendor_id],
          vendor_packing_slip_number: params[:vendor_packing_slip_number],
          vendor_invoice_number: params[:vendor_invoice_number],
          tracking_number: params[:tracking_number],
          received_at: params[:received_at].presence || Time.current,
          match_filter_purchase_order_id: params[:match_filter_purchase_order_id]
        )
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
      if params[:receiving_mode] == "vendor_shipment"
        create_vendor_shipment!
        return
      end

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
      load_match_workpad!
      @demand_impact = Receiving::ReceiptDemandImpactPreview.call(receipt: @receipt) if previewable_receipt?
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
        load_match_workpad!
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
      elsif %w[edit update].include?(action_name)
        relation = relation.includes(
          receipt_lines: [
            :product_variant,
            :purchase_order_line,
            { purchase_order_line: :demand_allocations }
          ],
          receipt_line_matches: [ :receipt_line, :purchase_order_line, :purchase_order ]
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
      return unless @receipt.draft?
      return unless previewable_receipt?

      document_hub = Purchasing::ReceiptDocumentHub.call(@receipt)
      @allocation_preview = Orders::ReceiptShowPresenter.new(receipt: @receipt, document_hub: document_hub)
    end

    def load_match_workpad!
      return unless @receipt.draft?
      return if @receipt.po_backed? && @receipt.purchase_order_id.present?

      @receipt_line_matches = @receipt.receipt_line_matches.order(:id)
      @match_candidates_by_line = @receipt.receipt_lines.each_with_object({}) do |line, hash|
        next if line.quantity_accepted.to_i.zero?

        hash[line.id] = Receiving::PoLineMatchCandidates.call(receipt_line: line)
      end
    end

    def previewable_receipt?
      (@receipt.po_backed? && @receipt.purchase_order_id.present?) ||
        @receipt.receiving_mode == "vendor_shipment" ||
        @receipt.receipt_line_matches.confirmed_matches.exists?
    end

    def create_vendor_shipment!
      vendor = Vendor.find(params[:vendor_id])
      @receipt = Receiving::CreateVendorShipmentReceipt.call!(
        store: orders_store,
        vendor: vendor,
        attrs: {
          match_filter_purchase_order_id: params[:match_filter_purchase_order_id].presence,
          vendor_packing_slip_number: params[:vendor_packing_slip_number],
          vendor_invoice_number: params[:vendor_invoice_number],
          tracking_number: params[:tracking_number],
          received_at: params[:received_at]
        }
      )
      record_audit!("receipt.created", @receipt)
      redirect_to edit_orders_receipt_path(@receipt), notice: "Vendor shipment receipt created. Add lines and match to POs."
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      render_vendor_shipment_form_errors!(e)
    end

    def render_vendor_shipment_form_errors!(error)
      @vendors = Vendor.active_records.order(:name)
      @purchase_orders = PurchaseOrder.where(store: orders_store, status: PurchaseOrder::RECEIVABLE_PO_STATUSES)
                                      .order(created_at: :desc)
      @vendor_shipment = OpenStruct.new(params.permit(
        :vendor_id,
        :vendor_packing_slip_number,
        :vendor_invoice_number,
        :tracking_number,
        :received_at,
        :match_filter_purchase_order_id
      ))
      flash.now[:alert] = vendor_shipment_error_message(error)
      render "new_vendor_shipment", status: :unprocessable_entity
    end

    def vendor_shipment_error_message(error)
      case error
      when ActiveRecord::RecordInvalid
        error.record.errors.full_messages.to_sentence
      else
        "Vendor not found."
      end
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
