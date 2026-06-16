# frozen_string_literal: true

module Setup
  class InventoryLocationsController < BaseController
    before_action :set_location, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.inventory_locations.view") }, only: %i[index show]
    before_action -> { authorize!("setup.inventory_locations.create") }, only: %i[new create]
    before_action -> { authorize!("setup.inventory_locations.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.inventory_locations.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.inventory_locations.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.inventory_locations.delete") }, only: :destroy

    def index
      @locations = InventoryLocation.includes(:store).order(:store_id, :sort_order, :name)
      @locations = @locations.where(store: current_store) unless globally_allowed?
    end

    def show
      @audit_events = AuditEvent.for_auditable(@location).limit(50)
    end

    def new
      @location = InventoryLocation.new(active: true, sort_order: 0, store: current_store)
    end

    def create
      @location = InventoryLocation.new(location_params)
      @location.store ||= current_store
      if @location.save
        record_audit!("inventory_location.created", @location)
        redirect_to setup_inventory_location_path(@location), notice: "Inventory location created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @location.update(location_params)
        record_audit!("inventory_location.updated", @location)
        redirect_to setup_inventory_location_path(@location), notice: "Inventory location updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @location.inventory_adjustment_lines.exists? || @location.inventory_ledger_entries.exists?
        redirect_to setup_inventory_location_path(@location), alert: "Location cannot be deleted. Inactivate instead."
      else
        @location.destroy!
        record_audit!("inventory_location.deleted", @location)
        redirect_to setup_inventory_locations_path, notice: "Inventory location deleted."
      end
    end

    def inactivate
      @location.inactivate!
      record_audit!("inventory_location.inactivated", @location)
      redirect_to setup_inventory_location_path(@location), notice: "Inventory location inactivated."
    end

    def reactivate
      @location.reactivate!
      record_audit!("inventory_location.reactivated", @location)
      redirect_to setup_inventory_location_path(@location), notice: "Inventory location reactivated."
    end

    private

    def set_location
      @location = InventoryLocation.find(params[:id])
    end

    def location_params
      params.require(:inventory_location).permit(:store_id, :name, :short_name, :sort_order, :active)
    end

    def globally_allowed?
      Authorization.globally_allowed?(user: current_user, permission_key: "setup.inventory_locations.view")
    end
  end
end
