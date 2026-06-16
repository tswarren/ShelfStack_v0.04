# frozen_string_literal: true

module Setup
  class VendorsController < BaseController
    before_action :set_vendor, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.vendors.view") }, only: %i[index show]
    before_action -> { authorize!("setup.vendors.create") }, only: %i[new create]
    before_action -> { authorize!("setup.vendors.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.vendors.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.vendors.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.vendors.delete") }, only: :destroy

    def index
      @vendors = Vendor.includes(:parent_vendor).order(:name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@vendor).limit(50)
    end

    def new
      @vendor = Vendor.new(active: true)
      @parent_vendors = Vendor.active_records.order(:name)
    end

    def create
      @vendor = Vendor.new(vendor_params)
      @parent_vendors = Vendor.active_records.order(:name)
      if @vendor.save
        record_audit!("vendor.created", @vendor)
        redirect_to setup_vendor_path(@vendor), notice: "Vendor created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @parent_vendors = Vendor.active_records.where.not(id: @vendor.id).order(:name)
    end

    def update
      @parent_vendors = Vendor.active_records.where.not(id: @vendor.id).order(:name)
      if @vendor.update(vendor_params)
        record_audit!("vendor.updated", @vendor)
        redirect_to setup_vendor_path(@vendor), notice: "Vendor updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @vendor.child_vendors.exists?
        redirect_to setup_vendor_path(@vendor), alert: "Vendor cannot be deleted. Inactivate instead."
      else
        @vendor.destroy
        record_audit!("vendor.deleted", @vendor)
        redirect_to setup_vendors_path, notice: "Vendor deleted."
      end
    end

    def inactivate
      @vendor.inactivate!
      record_audit!("vendor.inactivated", @vendor)
      redirect_to setup_vendor_path(@vendor), notice: "Vendor inactivated."
    end

    def reactivate
      @vendor.reactivate!
      record_audit!("vendor.reactivated", @vendor)
      redirect_to setup_vendor_path(@vendor), notice: "Vendor reactivated."
    end

    private

    def set_vendor
      @vendor = Vendor.find(params[:id])
    end

    def vendor_params
      params.require(:vendor).permit(
        :name, :parent_vendor_id, :default_pricing_model, :default_margin_target_bps,
        :default_supplier_discount_bps, :active
      )
    end
  end
end
