# frozen_string_literal: true

module Setup
  class WorkstationsController < BaseController
    before_action :set_workstation, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.workstations.view") }, only: %i[index show]
    before_action -> { authorize!("setup.workstations.create") }, only: %i[new create]
    before_action -> { authorize!("setup.workstations.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.workstations.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.workstations.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.workstations.delete") }, only: :destroy

    def index
      @workstations = Workstation.includes(:store).order(:workstation_code)
      @workstations = @workstations.where(store_id: params[:store_id]) if params[:store_id].present?
    end

    def show
      @audit_events = AuditEvent.for_auditable(@workstation).limit(50)
    end

    def new
      @workstation = Workstation.new(active: true)
      @stores = Store.active_records.order(:store_number)
    end

    def create
      @workstation = Workstation.new(workstation_params)
      if @workstation.save
        record_audit!("workstation.created", @workstation)
        redirect_to setup_workstation_path(@workstation), notice: "Workstation created."
      else
        @stores = Store.active_records.order(:store_number)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @stores = Store.active_records.order(:store_number)
    end

    def update
      if @workstation.update(workstation_params)
        record_audit!("workstation.updated", @workstation)
        redirect_to setup_workstation_path(@workstation), notice: "Workstation updated."
      else
        @stores = Store.active_records.order(:store_number)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @workstation.user_sessions.exists? || @workstation.workstation_assignments.exists?
        redirect_to setup_workstation_path(@workstation), alert: "Workstation cannot be deleted. Inactivate instead."
      else
        @workstation.destroy
        record_audit!("workstation.deleted", @workstation)
        redirect_to setup_workstations_path, notice: "Workstation deleted."
      end
    end

    def inactivate
      @workstation.inactivate!
      record_audit!("workstation.inactivated", @workstation)
      redirect_to setup_workstation_path(@workstation), notice: "Workstation inactivated."
    end

    def reactivate
      @workstation.reactivate!
      record_audit!("workstation.reactivated", @workstation)
      redirect_to setup_workstation_path(@workstation), notice: "Workstation reactivated."
    end

    private

    def set_workstation
      @workstation = Workstation.find(params[:id])
    end

    def workstation_params
      params.require(:workstation).permit(
        :store_id, :workstation_type, :workstation_number, :workstation_code, :name, :active
      )
    end
  end
end
