# frozen_string_literal: true

module Setup
  class StoreTaxCategoryRatesController < BaseController
    include StoreScopedAuthorization

    before_action :set_store_tax_category_rate, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.store_tax_category_rates.view") }, only: %i[index show]
    before_action -> { authorize!("setup.store_tax_category_rates.create") }, only: %i[new create]
    before_action -> { authorize!("setup.store_tax_category_rates.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.store_tax_category_rates.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.store_tax_category_rates.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.store_tax_category_rates.delete") }, only: :destroy
    before_action :authorize_mapping_store_access!, only: %i[show edit update destroy inactivate reactivate]

    def index
      @stores = accessible_stores_for("setup.store_tax_category_rates.view")
      @store_tax_category_rates = StoreTaxCategoryRate.includes(:store, :tax_category, :store_tax_rate)
                                                        .joins(:store)
                                                        .order("stores.store_number", :effective_on)
      if params[:store_id].present?
        @store_tax_category_rates = @store_tax_category_rates.where(store_id: params[:store_id])
      else
        @store_tax_category_rates = @store_tax_category_rates.where(store_id: @stores.select(:id))
      end
    end

    def show
      @audit_events = AuditEvent.for_auditable(@store_tax_category_rate).limit(50)
    end

    def new
      @store_tax_category_rate = StoreTaxCategoryRate.new(active: true, effective_on: Date.current)
      load_form_collections(create: true)
    end

    def create
      @store_tax_category_rate = StoreTaxCategoryRate.new(store_tax_category_rate_params)
      authorize_store_access!(@store_tax_category_rate.store, permission_key: "setup.store_tax_category_rates.create") if @store_tax_category_rate.store
      if @store_tax_category_rate.save
        record_audit!("store_tax_category_rate.created", @store_tax_category_rate)
        redirect_to setup_store_tax_category_rate_path(@store_tax_category_rate), notice: "Tax mapping created."
      else
        load_form_collections(create: true)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections(create: false)
    end

    def update
      if @store_tax_category_rate.update(store_tax_category_rate_params)
        record_audit!("store_tax_category_rate.updated", @store_tax_category_rate)
        redirect_to setup_store_tax_category_rate_path(@store_tax_category_rate), notice: "Tax mapping updated."
      else
        load_form_collections(create: false)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @store_tax_category_rate.destroy
      record_audit!("store_tax_category_rate.deleted", @store_tax_category_rate)
      redirect_to setup_store_tax_category_rates_path, notice: "Tax mapping deleted."
    end

    def inactivate
      @store_tax_category_rate.inactivate!
      record_audit!("store_tax_category_rate.inactivated", @store_tax_category_rate)
      redirect_to setup_store_tax_category_rate_path(@store_tax_category_rate), notice: "Tax mapping inactivated."
    end

    def reactivate
      @store_tax_category_rate.reactivate!
      record_audit!("store_tax_category_rate.reactivated", @store_tax_category_rate)
      redirect_to setup_store_tax_category_rate_path(@store_tax_category_rate), notice: "Tax mapping reactivated."
    end

    private

    def set_store_tax_category_rate
      @store_tax_category_rate = StoreTaxCategoryRate.find(params[:id])
    end

    def authorize_mapping_store_access!
      authorize_store_access!(@store_tax_category_rate.store, permission_key: action_permission_key)
    end

    def action_permission_key
      case action_name
      when "show" then "setup.store_tax_category_rates.view"
      when "edit", "update" then "setup.store_tax_category_rates.update"
      when "destroy" then "setup.store_tax_category_rates.delete"
      when "inactivate" then "setup.store_tax_category_rates.inactivate"
      when "reactivate" then "setup.store_tax_category_rates.reactivate"
      else "setup.store_tax_category_rates.view"
      end
    end

    def load_form_collections(create:)
      permission = create ? "setup.store_tax_category_rates.create" : "setup.store_tax_category_rates.update"
      @stores = accessible_stores_for(permission).active_records
      @tax_categories = TaxCategory.active_records.order(:sort_order, :name)
      store_id = @store_tax_category_rate.store_id || params.dig(:store_tax_category_rate, :store_id)
      @store_tax_rates = if store_id.present?
                           StoreTaxRate.active_records.where(store_id: store_id).order(:name)
                         else
                           StoreTaxRate.none
                         end
    end

    def store_tax_category_rate_params
      params.require(:store_tax_category_rate).permit(
        :store_id, :tax_category_id, :store_tax_rate_id, :effective_on, :ends_on, :active
      )
    end
  end
end
