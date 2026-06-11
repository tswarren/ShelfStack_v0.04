# frozen_string_literal: true

module Setup
  class StoreDisplayLocationsController < BaseController
    include StoreScopedAuthorization

    before_action :set_store_display_location, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.store_display_locations.view") }, only: %i[index show]
    before_action -> { authorize!("setup.store_display_locations.create") }, only: %i[new create]
    before_action -> { authorize!("setup.store_display_locations.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.store_display_locations.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.store_display_locations.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.store_display_locations.delete") }, only: :destroy
    before_action :authorize_store_display_location_access!, only: %i[show edit update destroy inactivate reactivate]

    def index
      @stores = accessible_stores_for("setup.store_display_locations.view")
      @store_display_locations = StoreDisplayLocation.includes(:store, :display_location)
                                                     .order("stores.store_number", "display_locations.sort_order")
      if params[:store_id].present?
        @store_display_locations = @store_display_locations.where(store_id: params[:store_id])
      else
        @store_display_locations = @store_display_locations.where(store_id: @stores.select(:id))
      end
    end

    def show
      @audit_events = AuditEvent.for_auditable(@store_display_location).limit(50)
    end

    def new
      @store_display_location = StoreDisplayLocation.new(active: true, linear_feet: 0)
      @stores = accessible_stores_for("setup.store_display_locations.create").active_records
      @display_locations = DisplayLocation.active_records.order(:sort_order, :name)
    end

    def create
      @store_display_location = StoreDisplayLocation.new(store_display_location_params)
      authorize_store_access!(@store_display_location.store, permission_key: "setup.store_display_locations.create") if @store_display_location.store
      @stores = accessible_stores_for("setup.store_display_locations.create").active_records
      @display_locations = DisplayLocation.active_records.order(:sort_order, :name)
      if @store_display_location.save
        record_audit!("store_display_location.created", @store_display_location)
        redirect_to setup_store_display_location_path(@store_display_location), notice: "Store display location created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @stores = accessible_stores_for("setup.store_display_locations.update").active_records
      @display_locations = DisplayLocation.active_records.order(:sort_order, :name)
    end

    def update
      @stores = accessible_stores_for("setup.store_display_locations.update").active_records
      @display_locations = DisplayLocation.active_records.order(:sort_order, :name)
      if @store_display_location.update(store_display_location_params)
        record_audit!("store_display_location.updated", @store_display_location)
        redirect_to setup_store_display_location_path(@store_display_location), notice: "Store display location updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @store_display_location.destroy
      record_audit!("store_display_location.deleted", @store_display_location)
      redirect_to setup_store_display_locations_path, notice: "Store display location deleted."
    end

    def inactivate
      @store_display_location.inactivate!
      record_audit!("store_display_location.inactivated", @store_display_location)
      redirect_to setup_store_display_location_path(@store_display_location), notice: "Store display location inactivated."
    end

    def reactivate
      @store_display_location.reactivate!
      record_audit!("store_display_location.reactivated", @store_display_location)
      redirect_to setup_store_display_location_path(@store_display_location), notice: "Store display location reactivated."
    end

    private

    def set_store_display_location
      @store_display_location = StoreDisplayLocation.find(params[:id])
    end

    def authorize_store_display_location_access!
      authorize_store_access!(@store_display_location.store, permission_key: action_permission_key)
    end

    def action_permission_key
      case action_name
      when "show" then "setup.store_display_locations.view"
      when "edit", "update" then "setup.store_display_locations.update"
      when "destroy" then "setup.store_display_locations.delete"
      when "inactivate" then "setup.store_display_locations.inactivate"
      when "reactivate" then "setup.store_display_locations.reactivate"
      else "setup.store_display_locations.view"
      end
    end

    def store_display_location_params
      params.require(:store_display_location).permit(:store_id, :display_location_id, :linear_feet, :active)
    end
  end
end
