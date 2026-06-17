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
      @audit_events = AuditEvent.for_auditable(@receipt).limit(50)
    end

    def new
      @receipt = Receipt.new(
        store: orders_store,
        receipt_type: params[:receipt_type].presence || "direct",
        status: "draft"
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
        render :edit, status: :unprocessable_entity
      end
    end

    def post
      Purchasing::PostReceipt.call(receipt: @receipt, posted_by_user: current_user)
      redirect_to orders_receipt_path(@receipt), notice: "Receipt posted."
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
      @receipt = Receipt.where(store: orders_store).find(params[:id])
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

    def receipt_params
      params.require(:receipt).permit(
        :vendor_id,
        :purchase_order_id,
        :receipt_type,
        receipt_lines_attributes: %i[
          id line_number product_variant_id purchase_order_line_id
          quantity_expected quantity_received quantity_accepted quantity_rejected
          unit_list_price_cents supplier_discount_bps unit_cost_cents _destroy
        ]
      )
    end
  end
end
