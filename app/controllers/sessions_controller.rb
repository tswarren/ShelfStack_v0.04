# frozen_string_literal: true

class SessionsController < ApplicationController
  layout "auth"

  skip_before_action :enforce_session_state, only: %i[new create destroy]
  before_action :redirect_if_authenticated, only: %i[new create]

  def new
    @workstation_assignment = WorkstationAssignmentService.resolve_from_cookie(cookies)
  end

  def create
    result = AuthenticationService.authenticate(
      username: params[:username],
      password: params[:password]
    )

    unless result[:success]
      flash.now[:alert] = result[:message]
      @workstation_assignment = WorkstationAssignmentService.resolve_from_cookie(cookies)
      render :new, status: :unprocessable_entity
      return
    end

    user = result[:user]
    assignment = WorkstationAssignmentService.resolve_from_cookie(cookies)

    if assignment.nil?
      if Authorization.allowed?(user: user, permission_key: "workstations.assign_browser", store: nil)
        session = SessionLifecycle.login(
          user: user,
          workstation_assignment: nil,
          request: request,
          cookies: cookies,
          allow_missing_workstation: true
        )
        redirect_to new_workstation_assignment_path, notice: "Assign this browser to a workstation to continue."
        return
      else
        flash.now[:alert] = "This browser must be assigned to a workstation before login."
        @workstation_assignment = nil
        render :new, status: :unprocessable_entity
        return
      end
    end

    session = SessionLifecycle.login(
      user: user,
      workstation_assignment: assignment,
      request: request,
      cookies: cookies
    )

    if user.force_password_change?
      redirect_to edit_password_path, notice: "You must change your password before continuing."
    else
      flash[:notice] = login_welcome_message(user)
      redirect_to root_path
    end
  end

  def destroy
    if current_user_session
      SessionLifecycle.logout(session: current_user_session, actor: current_user, cookies: cookies)
    end
    redirect_to login_path, notice: "You have been logged out."
  end

  private

  def redirect_if_authenticated
    redirect_to root_path if current_user_session&.active?
  end

  def can_assign_workstation?
    false
  end

  def login_welcome_message(user)
    if user.previous_login_at.present?
      "Welcome, #{user.display_name}. You last logged in at #{display_time(user.previous_login_at)}."
    else
      "Welcome, #{user.display_name}."
    end
  end
end
