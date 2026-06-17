# frozen_string_literal: true

module Setup
  class ProductVariantVendorsController < BaseController
    before_action :set_product_variant_vendor, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.product_variant_vendors.view") }, only: %i[index show]
    before_action -> { authorize!("setup.product_variant_vendors.create") }, only: %i[new create]
    before_action -> { authorize!("setup.product_variant_vendors.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.product_variant_vendors.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.product_variant_vendors.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.product_variant_vendors.delete") }, only: :destroy

    def index
      @product_variant_vendors = ProductVariantVendor
        .includes(product_variant: :product, vendor: [])
        .joins(:product_variant, :vendor)
        .order("product_variants.sku", "vendors.name")
    end

    def show
      @audit_events = AuditEvent.for_auditable(@product_variant_vendor).limit(50)
    end

    def new
      @product_variant_vendor = ProductVariantVendor.new(active: true, preferred: false)
      load_form_collections
    end

    def create
      @product_variant_vendor = ProductVariantVendor.new(product_variant_vendor_params)
      load_form_collections
      if @product_variant_vendor.save
        record_audit!("product_variant_vendor.created", @product_variant_vendor)
        redirect_to setup_product_variant_vendor_path(@product_variant_vendor), notice: "Variant vendor created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      load_form_collections
      if @product_variant_vendor.update(product_variant_vendor_params)
        record_audit!("product_variant_vendor.updated", @product_variant_vendor)
        redirect_to setup_product_variant_vendor_path(@product_variant_vendor), notice: "Variant vendor updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @product_variant_vendor.destroy!
      record_audit!("product_variant_vendor.deleted", @product_variant_vendor)
      redirect_to setup_product_variant_vendors_path, notice: "Variant vendor deleted."
    end

    def inactivate
      @product_variant_vendor.inactivate!
      record_audit!("product_variant_vendor.inactivated", @product_variant_vendor)
      redirect_to setup_product_variant_vendor_path(@product_variant_vendor), notice: "Variant vendor inactivated."
    end

    def reactivate
      @product_variant_vendor.reactivate!
      record_audit!("product_variant_vendor.reactivated", @product_variant_vendor)
      redirect_to setup_product_variant_vendor_path(@product_variant_vendor), notice: "Variant vendor reactivated."
    end

    private

    def set_product_variant_vendor
      @product_variant_vendor = ProductVariantVendor.find(params[:id])
    end

    def load_form_collections
      @product_variants = ProductVariant.active_records.includes(:product).order(:sku).limit(500)
      @vendors = Vendor.active_records.order(:name)
      @returnability_options = ReturnabilityStatus::RETURNABILITY_STATUSES
    end

    def product_variant_vendor_params
      params.require(:product_variant_vendor).permit(
        :product_variant_id, :vendor_id, :vendor_item_number, :supplier_discount_bps,
        :returnability_status, :preferred, :active
      )
    end
  end
end
