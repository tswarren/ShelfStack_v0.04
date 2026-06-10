# frozen_string_literal: true

module Setup
  class StoresController < BaseController
    before_action :set_store, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.stores.view") }, only: %i[index show]
    before_action -> { authorize!("setup.stores.create") }, only: %i[new create]
    before_action -> { authorize!("setup.stores.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.stores.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.stores.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.stores.delete") }, only: :destroy

    def index
      @stores = Store.order(:store_number)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@store).limit(50)
    end

    def new
      @store = Store.new(active: true, country_code: "US", time_zone: "America/New_York")
    end

    def create
      @store = Store.new(store_params)
      if @store.save
        record_audit!("store.created", @store)
        redirect_to setup_store_path(@store), notice: "Store created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @store.update(store_params)
        record_audit!("store.updated", @store)
        redirect_to setup_store_path(@store), notice: "Store updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @store.workstations.exists? || @store.user_sessions.exists?
        redirect_to setup_store_path(@store), alert: "Store cannot be deleted. Inactivate instead."
      else
        @store.destroy
        record_audit!("store.deleted", @store)
        redirect_to setup_stores_path, notice: "Store deleted."
      end
    end

    def inactivate
      @store.inactivate!
      record_audit!("store.inactivated", @store)
      redirect_to setup_store_path(@store), notice: "Store inactivated."
    end

    def reactivate
      @store.reactivate!
      record_audit!("store.reactivated", @store)
      redirect_to setup_store_path(@store), notice: "Store reactivated."
    end

    private

    def set_store
      @store = Store.find(params[:id])
    end

    def store_params
      params.require(:store).permit(
        :store_number, :store_group, :name, :shopping_center, :address_line1, :address_line2,
        :city, :country_code, :region_code, :postal_code, :phone, :fax, :email, :website_url,
        :time_zone, :active
      )
    end
  end
end
