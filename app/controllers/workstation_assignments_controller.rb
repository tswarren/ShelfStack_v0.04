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
    path = authentication_completion_path(current_user)
    notice = if path == root_path
               "Browser assigned to #{workstation.name}."
    else
               authentication_completion_notice(current_user)
    end
    redirect_to path, notice: notice
  end

  private

  def require_assign_permission
    authorize!("workstations.assign_browser")
  end
end
