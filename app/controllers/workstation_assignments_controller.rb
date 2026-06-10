# frozen_string_literal: true

class WorkstationAssignmentsController < ApplicationController
  layout "auth"

  before_action :require_active_session
  before_action :require_assign_permission

  def new
    @stores = Store.active_records.order(:store_number)
    @workstations = Workstation.active_records.includes(:store).order(:workstation_code)
  end

  def create
    workstation = Workstation.active_records.find(params[:workstation_id])
    WorkstationAssignmentService.assign!(
      workstation: workstation,
      assigned_by: current_user,
      cookies: cookies
    )
    current_user_session.update!(store: workstation.store, workstation: workstation)
    Current.store = workstation.store
    Current.workstation = workstation
    redirect_to root_path, notice: "Browser assigned to #{workstation.name}."
  end

  private

  def require_assign_permission
    authorize!("workstations.assign_browser")
  end
end
