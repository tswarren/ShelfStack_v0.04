# frozen_string_literal: true

module Orders
  class ReturnsToVendorController < BaseController
    before_action :set_return_to_vendor, only: %i[show edit update post cancel]
    before_action -> { authorize!("orders.returns_to_vendor.view") }, only: %i[index show]
    before_action -> { authorize!("orders.returns_to_vendor.create") }, only: %i[new create edit update]
    before_action -> { authorize!("orders.returns_to_vendor.post") }, only: :post
    before_action -> { authorize!("orders.returns_to_vendor.cancel") }, only: :cancel

    def index
      @returns_to_vendor = ReturnToVendor
        .includes(:vendor)
        .where(store: orders_store)
        .order(created_at: :desc)
    end

    def show
      @document_hub = Purchasing::ReturnToVendorDocumentHub.call(@return_to_vendor)
      @show_presenter = Orders::ReturnToVendorShowPresenter.new(
        return_to_vendor: @return_to_vendor,
        document_hub: @document_hub
      )
      @audit_events = AuditEvent.for_auditable(@return_to_vendor).limit(50)
    end

    def new
      @return_to_vendor = ReturnToVendor.new(store: orders_store, status: "draft")
      build_initial_line
      load_form_collections
    end

    def create
      @return_to_vendor = ReturnToVendor.new(return_to_vendor_params)
      @return_to_vendor.store = orders_store
      @return_to_vendor.status = "draft"

      if @return_to_vendor.save
        record_audit!("return_to_vendor.created", @return_to_vendor)
        redirect_to orders_returns_to_vendor_path(@return_to_vendor), notice: "Draft return to vendor created."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      redirect_to orders_returns_to_vendor_path(@return_to_vendor), alert: "Posted returns cannot be edited." unless @return_to_vendor.draft?
      load_form_collections
    end

    def update
      unless @return_to_vendor.draft?
        redirect_to orders_returns_to_vendor_path(@return_to_vendor), alert: "Posted returns cannot be edited."
        return
      end

      if @return_to_vendor.update(return_to_vendor_params)
        record_audit!("return_to_vendor.updated", @return_to_vendor)
        redirect_to orders_returns_to_vendor_path(@return_to_vendor), notice: "Draft return to vendor updated."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def post
      Purchasing::PostReturnToVendor.call(return_to_vendor: @return_to_vendor, posted_by_user: current_user)
      redirect_to orders_returns_to_vendor_path(@return_to_vendor), notice: "Return to vendor posted."
    rescue Purchasing::PostReturnToVendor::PostingError => e
      redirect_to orders_returns_to_vendor_path(@return_to_vendor), alert: e.message
    end

    def cancel
      unless @return_to_vendor.draft?
        redirect_to orders_returns_to_vendor_path(@return_to_vendor), alert: "Only draft returns can be cancelled."
        return
      end

      @return_to_vendor.update!(status: "cancelled")
      record_audit!("return_to_vendor.cancelled", @return_to_vendor)
      redirect_to orders_returns_to_vendor_index_path, notice: "Return to vendor cancelled."
    end

    private

    def set_return_to_vendor
      @return_to_vendor = ReturnToVendor.where(store: orders_store).find(params[:id])
    end

    def load_form_collections
      @vendors = Vendor.active_records.order(:name)
    end

    def build_initial_line
      if params[:product_variant_id].present?
        variant = ProductVariant.active_records.find_by(id: params[:product_variant_id])
        if variant
          @return_to_vendor.return_to_vendor_lines.build(
            product_variant: variant,
            quantity: 1
          )
          return
        end
      end

      @return_to_vendor.return_to_vendor_lines.build
    end

    def return_to_vendor_params
      params.require(:return_to_vendor).permit(
        :vendor_id,
        :notes,
        return_to_vendor_lines_attributes: %i[
          id line_number product_variant_id quantity unit_cost_cents credit_amount_cents _destroy
        ]
      )
    end
  end
end
