# frozen_string_literal: true

module Setup
  class StoreTaxRatesController < BaseController
    include StoreScopedAuthorization

    before_action :set_store_tax_rate, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.store_tax_rates.view") }, only: %i[index show]
    before_action -> { authorize!("setup.store_tax_rates.create") }, only: %i[new create]
    before_action -> { authorize!("setup.store_tax_rates.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.store_tax_rates.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.store_tax_rates.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.store_tax_rates.delete") }, only: :destroy
    before_action :authorize_store_tax_rate_access!, only: %i[show edit update destroy inactivate reactivate]

    def index
      @stores = accessible_stores_for("setup.store_tax_rates.view")
      @store_tax_rates = StoreTaxRate.includes(:store).order("stores.store_number", :name)
      if params[:store_id].present?
        @store_tax_rates = @store_tax_rates.where(store_id: params[:store_id])
      else
        @store_tax_rates = @store_tax_rates.where(store_id: @stores.select(:id))
      end
    end

    def show
      @audit_events = AuditEvent.for_auditable(@store_tax_rate).limit(50)
    end

    def new
      @store_tax_rate = StoreTaxRate.new(active: true, tax_rate_bps: 0)
      @stores = accessible_stores_for("setup.store_tax_rates.create").active_records
    end

    def create
      @store_tax_rate = StoreTaxRate.new(store_tax_rate_params)
      authorize_store_access!(@store_tax_rate.store, permission_key: "setup.store_tax_rates.create") if @store_tax_rate.store
      if @store_tax_rate.save
        record_audit!("store_tax_rate.created", @store_tax_rate)
        redirect_to setup_store_tax_rate_path(@store_tax_rate), notice: "Store tax rate created."
      else
        @stores = accessible_stores_for("setup.store_tax_rates.create").active_records
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @stores = accessible_stores_for("setup.store_tax_rates.update").active_records
    end

    def update
      if @store_tax_rate.update(store_tax_rate_params)
        record_audit!("store_tax_rate.updated", @store_tax_rate)
        redirect_to setup_store_tax_rate_path(@store_tax_rate), notice: "Store tax rate updated."
      else
        @stores = accessible_stores_for("setup.store_tax_rates.update").active_records
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @store_tax_rate.store_tax_category_rates.exists?
        redirect_to setup_store_tax_rate_path(@store_tax_rate), alert: "Store tax rate cannot be deleted. Inactivate instead."
      else
        @store_tax_rate.destroy
        record_audit!("store_tax_rate.deleted", @store_tax_rate)
        redirect_to setup_store_tax_rates_path, notice: "Store tax rate deleted."
      end
    end

    def inactivate
      @store_tax_rate.inactivate!
      record_audit!("store_tax_rate.inactivated", @store_tax_rate)
      redirect_to setup_store_tax_rate_path(@store_tax_rate), notice: "Store tax rate inactivated."
    end

    def reactivate
      @store_tax_rate.reactivate!
      record_audit!("store_tax_rate.reactivated", @store_tax_rate)
      redirect_to setup_store_tax_rate_path(@store_tax_rate), notice: "Store tax rate reactivated."
    end

    private

    def set_store_tax_rate
      @store_tax_rate = StoreTaxRate.find(params[:id])
    end

    def authorize_store_tax_rate_access!
      authorize_store_access!(@store_tax_rate.store, permission_key: action_permission_key)
    end

    def action_permission_key
      case action_name
      when "show" then "setup.store_tax_rates.view"
      when "edit", "update" then "setup.store_tax_rates.update"
      when "destroy" then "setup.store_tax_rates.delete"
      when "inactivate" then "setup.store_tax_rates.inactivate"
      when "reactivate" then "setup.store_tax_rates.reactivate"
      else "setup.store_tax_rates.view"
      end
    end

    def store_tax_rate_params
      params.require(:store_tax_rate).permit(:store_id, :name, :short_name, :tax_identifier, :tax_rate_bps, :active)
    end
  end
end
