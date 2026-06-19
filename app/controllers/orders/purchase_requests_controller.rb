# frozen_string_literal: true

module Orders
  class PurchaseRequestsController < BaseController
    BuildableLineEntry = Data.define(:line, :remaining_quantity)

    before_action :set_purchase_request, only: %i[show edit update cancel build_purchase_order create_purchase_order]
    before_action -> { authorize!("orders.purchase_requests.view") }, only: %i[index show build_purchase_order]
    before_action -> { authorize!("orders.purchase_requests.create") }, only: %i[new create edit update]
    before_action -> { authorize!("orders.purchase_orders.create") }, only: %i[build_purchase_order create_purchase_order]
    before_action -> { authorize!("orders.purchase_requests.cancel") }, only: :cancel

    def index
      @purchase_requests = PurchaseRequest
        .includes(:purchase_request_lines)
        .where(store: orders_store)
        .order(created_at: :desc)
    end

    def show
      @document_hub = Purchasing::PurchaseRequestDocumentHub.call(@purchase_request)
      @show_presenter = Orders::PurchaseRequestShowPresenter.new(
        purchase_request: @purchase_request,
        document_hub: @document_hub
      )
      @audit_events = AuditEvent.for_auditable(@purchase_request).limit(50)
      @buildable = @purchase_request.buildable?
    end

    def build_purchase_order
      unless @purchase_request.buildable?
        redirect_to orders_purchase_request_path(@purchase_request), alert: "No lines are ready to add to a purchase order."
        return
      end

      @buildable_lines = @purchase_request.buildable_lines.filter_map do |line|
        remaining = line.remaining_quantity
        next if remaining <= 0

        BuildableLineEntry.new(line: line, remaining_quantity: remaining)
      end

      if @buildable_lines.empty?
        redirect_to orders_purchase_request_path(@purchase_request), alert: "No lines have remaining quantity to order."
        return
      end
      @vendors = Vendor.active_records.order(:name)
      @notes = @purchase_request.notes
    end

    def create_purchase_order
      unless @purchase_request.buildable?
        redirect_to orders_purchase_request_path(@purchase_request), alert: "No lines are ready to add to a purchase order."
        return
      end

      vendor = Vendor.active_records.find_by(id: params[:vendor_id])
      if vendor.blank?
        redirect_to build_purchase_order_orders_purchase_request_path(@purchase_request), alert: "Vendor is required."
        return
      end

      line_ids = Array(params[:purchase_request_line_ids]).map(&:to_i).uniq
      lines = @purchase_request.purchase_request_lines.where(id: line_ids).select do |line|
        PurchaseRequest::BUILDABLE_LINE_STATUSES.include?(line.status) && line.remaining_quantity.positive?
      end

      if lines.empty?
        redirect_to build_purchase_order_orders_purchase_request_path(@purchase_request), alert: "No lines are ready to add to a purchase order."
        return
      end

      purchase_order = Purchasing::BuildPurchaseOrder.call(
        store: orders_store,
        vendor: vendor,
        created_by_user: current_user,
        purchase_request_lines: lines,
        notes: params[:notes].presence,
        line_quantities: params.fetch(:line_quantities, {}).to_unsafe_h
      )
      PurchaseRequest.refresh_statuses_for_lines!(lines)

      redirect_to orders_purchase_order_path(purchase_order), notice: "Draft purchase order created from purchase request."
    rescue Purchasing::BuildPurchaseOrder::BuildError => e
      redirect_to build_purchase_order_orders_purchase_request_path(@purchase_request), alert: e.message
    end

    def new
      @purchase_request = PurchaseRequest.new(store: orders_store, status: "open")
      build_initial_line
      load_form_collections
    end

    def create
      @purchase_request = PurchaseRequest.new(purchase_request_params)
      @purchase_request.store = orders_store
      @purchase_request.status = "open"

      if @purchase_request.save
        record_audit!("purchase_request.created", @purchase_request)
        redirect_to orders_purchase_request_path(@purchase_request), notice: "Purchase request created."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      redirect_to orders_purchase_request_path(@purchase_request), alert: "Closed purchase requests cannot be edited." if purchase_request_closed?(@purchase_request)
      load_form_collections
    end

    def update
      if purchase_request_closed?(@purchase_request)
        redirect_to orders_purchase_request_path(@purchase_request), alert: "Closed purchase requests cannot be edited."
        return
      end

      if @purchase_request.update(purchase_request_params)
        record_audit!("purchase_request.updated", @purchase_request)
        redirect_to orders_purchase_request_path(@purchase_request), notice: "Purchase request updated."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def cancel
      if purchase_request_closed?(@purchase_request)
        redirect_to orders_purchase_request_path(@purchase_request), alert: "This purchase request cannot be cancelled."
        return
      end

      PurchaseRequest.transaction do
        @purchase_request.update!(status: "cancelled")
        @purchase_request.purchase_request_lines.update_all(status: "cancelled")
      end
      record_audit!("purchase_request.cancelled", @purchase_request)
      redirect_to orders_purchase_requests_path, notice: "Purchase request cancelled."
    end

    private

    def set_purchase_request
      relation = PurchaseRequest.where(store: orders_store)
      if action_name == "show"
        relation = relation.includes(
          purchase_request_lines: [ :product_variant, { purchase_order_line: :purchase_order } ]
        )
      end
      @purchase_request = relation.find(params[:id])
    end

    def purchase_request_closed?(purchase_request)
      %w[cancelled closed].include?(purchase_request.status)
    end

    def load_form_collections
      @line_status_options = PurchaseRequestLine::STATUSES
    end

    def build_initial_line
      if params[:product_variant_id].present?
        variant = ProductVariant.active_records.find_by(id: params[:product_variant_id])
        if variant
          @purchase_request.purchase_request_lines.build(
            product_variant: variant,
            requested_quantity: 1,
            request_reason: "tbo",
            status: "open"
          )
          return
        end
      end

      @purchase_request.purchase_request_lines.build
    end

    def purchase_request_params
      params.require(:purchase_request).permit(
        :notes,
        purchase_request_lines_attributes: %i[
          id line_number product_variant_id requested_quantity request_reason status _destroy
        ]
      )
    end
  end
end
