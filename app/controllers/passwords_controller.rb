# frozen_string_literal: true

class PasswordsController < ApplicationController
  layout "auth"

  before_action :require_active_session

  def edit
  end

  def update
    user = current_user

    unless user.authenticate(params[:current_password])
      flash.now[:alert] = "Current password is incorrect."
      render :edit, status: :unprocessable_entity
      return
    end

    user.password = params[:password]
    user.password_confirmation = params[:password_confirmation]
    user.force_password_change = false
    user.password_changed_at = Time.current

    if user.save
      AuditEvents.record!(actor: user, event_name: "user.password_changed", auditable: user)
      redirect_to root_path, notice: "Password updated successfully."
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
