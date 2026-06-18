# frozen_string_literal: true

module Setup
  class ProductVendorsController < BaseController
    before_action :set_product_vendor, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.product_vendors.view") }, only: %i[index show]
    before_action -> { authorize!("setup.product_vendors.create") }, only: %i[new create]
    before_action -> { authorize!("setup.product_vendors.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.product_vendors.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.product_vendors.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.product_vendors.delete") }, only: :destroy

    def index
      @product_vendors = ProductVendor.includes(:product, :vendor).joins(:product, :vendor).order("products.name", "vendors.name")
    end

    def show
      @audit_events = AuditEvent.for_auditable(@product_vendor).limit(50)
    end

    def new
      @product_vendor = ProductVendor.new(active: true, preferred: false)
      load_form_collections
    end

    def create
      @product_vendor = ProductVendor.new(product_vendor_params)
      load_form_collections
      if @product_vendor.save
        record_audit!("product_vendor.created", @product_vendor)
        redirect_to setup_product_vendor_path(@product_vendor), notice: "Product vendor created."
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
        redirect_to setup_product_vendor_path(@product_vendor), notice: "Product vendor updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @product_vendor.destroy!
      record_audit!("product_vendor.deleted", @product_vendor)
      redirect_to setup_product_vendors_path, notice: "Product vendor deleted."
    end

    def inactivate
      @product_vendor.inactivate!
      record_audit!("product_vendor.inactivated", @product_vendor)
      redirect_to setup_product_vendor_path(@product_vendor), notice: "Product vendor inactivated."
    end

    def reactivate
      @product_vendor.reactivate!
      record_audit!("product_vendor.reactivated", @product_vendor)
      redirect_to setup_product_vendor_path(@product_vendor), notice: "Product vendor reactivated."
    end

    private

    def set_product_vendor
      @product_vendor = ProductVendor.find(params[:id])
    end

    def load_form_collections
      @products = Product.active_records.order(:name).limit(500)
      @vendors = Vendor.active_records.order(:name)
      @returnability_options = ReturnabilityStatus::RETURNABILITY_STATUSES
    end

    def product_vendor_params
      params.require(:product_vendor).permit(
        :product_id, :vendor_id, :vendor_item_number, :supplier_discount_bps,
        :returnability_status, :preferred, :active
      )
    end
  end
end
