# frozen_string_literal: true

module Items
  class ProductVendorsController < BaseController
    before_action :set_product
    before_action :set_product_vendor, only: %i[edit update]
    before_action -> { authorize!("setup.product_vendors.view") }, only: %i[new edit]
    before_action -> { authorize!("setup.product_vendors.create") }, only: :create
    before_action -> { authorize!("setup.product_vendors.update") }, only: :update

    def new
      @product_vendor = ProductVendor.new(
        product: @product,
        vendor_id: params[:vendor_id],
        active: true,
        preferred: false
      )
      load_form_collections
    end

    def create
      @product_vendor = ProductVendor.new(product_vendor_params)
      @product_vendor.product = @product
      load_form_collections

      if @product_vendor.save
        record_audit!("product_vendor.created", @product_vendor)
        redirect_to item_return_path, notice: "Product vendor created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      load_form_collections
      if @product_vendor.update(product_vendor_params)
        record_audit!("product_vendor.updated", @product_vendor)
        redirect_to item_return_path, notice: "Product vendor updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_product
      @product = Product.find(params[:product_id])
    end

    def set_product_vendor
      @product_vendor = @product.product_vendors.find(params[:id])
    end

    def load_form_collections
      @vendors = Vendor.active_records.order(:name)
      @returnability_options = ReturnabilityStatus::RETURNABILITY_STATUSES
    end

    def product_vendor_params
      params.require(:product_vendor).permit(
        :vendor_id, :vendor_item_number, :supplier_discount_bps,
        :returnability_status, :preferred, :active
      )
    end

    def item_return_path
      Items::ReturnPath.for(
        record: @product,
        return_to: params[:return_to].presence || "item",
        tab: params[:return_to] == "from_tbo" ? nil : "item_setup",
        anchor: params[:return_to] == "from_tbo" ? nil : "vendor-sourcing",
        from_tbo_filters: from_tbo_return_filters
      )
    end

    def from_tbo_return_filters
      {
        view: params[:from_tbo_view],
        vendor_id: params[:from_tbo_vendor_id],
        sourced_only: params[:from_tbo_sourced_only],
        department_id: params[:from_tbo_department_id],
        format_id: params[:from_tbo_format_id]
      }.compact
    end
  end
end
