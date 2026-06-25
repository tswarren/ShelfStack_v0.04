# frozen_string_literal: true

class SessionLocksController < ApplicationController
  layout "auth"

  skip_before_action :enforce_session_state
  before_action :require_locked_session, only: %i[show create]

  def show
  end

  def create
    begin
      return_path = SessionReturnLocation.redirect_path_for(current_user_session)
      if current_user.pin_set?
        SessionLifecycle.unlock!(session: current_user_session, user: current_user, pin: params[:pin])
      else
        SessionLifecycle.unlock!(session: current_user_session, user: current_user, password: params[:password])
      end
      redirect_to return_path || root_path, notice: "Session unlocked."
    rescue SessionLifecycle::Error
      flash.now[:alert] = current_user.pin_set? ? "Invalid PIN." : "Invalid password."
      render :show, status: :unprocessable_entity
    end
  end

  def lock
    require_active_session
    return if performed?

    SessionLifecycle.lock!(
      session: current_user_session,
      actor: current_user,
      return_path: SessionReturnLocation.sanitize(params[:return_to])
    )
    redirect_to session_unlock_path
  end

  private

  def require_locked_session
    unless current_user_session&.locked?
      redirect_to root_path
    end
  end
end
