# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  include ApplicationHelper

  helper_method :current_user, :current_store, :current_workstation, :current_user_session,
                :current_workstation_assignment, :display_time

  before_action :load_request_context
  before_action :enforce_session_state
  before_action :enforce_onboarding_requirements

  ONBOARDING_EXEMPT_CONTROLLERS = %w[sessions session_locks passwords pins workstation_assignments].freeze

  private

  def load_request_context
    @workstation_assignment = WorkstationAssignmentService.resolve_from_cookie(cookies)
    @user_session = SessionLifecycle.load_context!(cookies: cookies, workstation_assignment: @workstation_assignment)
  end

  def enforce_session_state
    return unless @user_session

    if @user_session.locked? && !session_lock_allowed?
      redirect_to session_unlock_path
    elsif @user_session.terminal?
      SessionLifecycle.clear_session_cookie(cookies)
      SessionLifecycle.reset_current_context
      redirect_to login_path, alert: "Your session has ended."
    elsif @user_session.active?
      SessionLifecycle.touch_activity!(@user_session)
    end
  end

  def session_lock_allowed?
    controller_name == "session_locks" || (controller_name == "sessions" && action_name.in?(%w[destroy]))
  end

  def current_user
    Current.user
  end

  def current_store
    Current.store
  end

  def current_workstation
    Current.workstation
  end

  def current_user_session
    Current.user_session
  end

  def current_workstation_assignment
    Current.workstation_assignment
  end

  def require_authentication
    return if current_user_session&.active? || current_user_session&.locked?

    redirect_to login_path, alert: "Please log in to continue."
  end

  def require_active_session
    require_authentication
    return unless performed?

    redirect_to session_unlock_path if current_user_session&.locked?
  end

  def authorize!(permission_key)
    return if Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)

    redirect_to root_path, alert: "You are not authorized to perform that action."
  end

  def enforce_onboarding_requirements
    return if ONBOARDING_EXEMPT_CONTROLLERS.include?(controller_name)
    return unless current_user_session&.active?

    user = current_user
    return unless user

    if user.force_password_change?
      redirect_to edit_password_path, notice: "You must change your password before continuing."
      return
    end

    return if user.pin_set?

    redirect_to edit_pin_path, notice: "You must set a PIN before continuing."
  end

  def authentication_completion_path(user)
    return edit_password_path if user.force_password_change?
    return edit_pin_path unless user.pin_set?

    root_path
  end

  def authentication_completion_notice(user)
    if user.force_password_change?
      "You must change your password before continuing."
    elsif !user.pin_set?
      "You must set a PIN before continuing."
    else
      login_welcome_message(user)
    end
  end

  def login_welcome_message(user)
    if user.previous_login_at.present?
      "Welcome, #{user.display_name}. You last logged in at #{display_time(user.previous_login_at)}."
    else
      "Welcome, #{user.display_name}."
    end
  end
end
