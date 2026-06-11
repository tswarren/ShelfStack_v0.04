# frozen_string_literal: true

module Setup
  class DisplayLocationsController < BaseController
    before_action :set_display_location, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.display_locations.view") }, only: %i[index show]
    before_action -> { authorize!("setup.display_locations.create") }, only: %i[new create]
    before_action -> { authorize!("setup.display_locations.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.display_locations.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.display_locations.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.display_locations.delete") }, only: :destroy

    def index
      @display_locations = DisplayLocation.includes(:parent).order(:sort_order, :name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@display_location).limit(50)
    end

    def new
      @display_location = DisplayLocation.new(active: true)
      @parents = DisplayLocation.active_records.order(:sort_order, :name)
    end

    def create
      @display_location = DisplayLocation.new(display_location_params)
      @parents = DisplayLocation.active_records.order(:sort_order, :name)
      if @display_location.save
        record_audit!("display_location.created", @display_location)
        redirect_to setup_display_location_path(@display_location), notice: "Display location created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @parents = DisplayLocation.active_records.where.not(id: @display_location.id).order(:sort_order, :name)
    end

    def update
      @parents = DisplayLocation.active_records.where.not(id: @display_location.id).order(:sort_order, :name)
      if @display_location.update(display_location_params)
        record_audit!("display_location.updated", @display_location)
        redirect_to setup_display_location_path(@display_location), notice: "Display location updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @display_location.children.exists? || @display_location.store_display_locations.exists? ||
         @display_location.products.exists? || @display_location.product_variants.exists?
        redirect_to setup_display_location_path(@display_location), alert: "Display location cannot be deleted. Inactivate instead."
      else
        @display_location.destroy
        record_audit!("display_location.deleted", @display_location)
        redirect_to setup_display_locations_path, notice: "Display location deleted."
      end
    end

    def inactivate
      @display_location.inactivate!
      record_audit!("display_location.inactivated", @display_location)
      redirect_to setup_display_location_path(@display_location), notice: "Display location inactivated."
    end

    def reactivate
      @display_location.reactivate!
      record_audit!("display_location.reactivated", @display_location)
      redirect_to setup_display_location_path(@display_location), notice: "Display location reactivated."
    end

    private

    def set_display_location
      @display_location = DisplayLocation.find(params[:id])
    end

    def display_location_params
      params.require(:display_location).permit(:name, :short_name, :parent_id, :sort_order, :active)
    end
  end
end
