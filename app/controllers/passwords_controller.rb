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

    if params[:password].blank?
      flash.now[:alert] = "New password can't be blank."
      render :edit, status: :unprocessable_entity
      return
    end

    if params[:password_confirmation].blank?
      flash.now[:alert] = "Password confirmation can't be blank."
      render :edit, status: :unprocessable_entity
      return
    end

    user.password = params[:password]
    user.password_confirmation = params[:password_confirmation]
    user.force_password_change = false
    user.password_changed_at = Time.current

    if user.save
      AuditEvents.record!(actor: user, event_name: "user.password_changed", auditable: user)
      if user.pin_set?
        redirect_to root_path, notice: "Password updated successfully."
      else
        redirect_to edit_pin_path, notice: "Password updated successfully. You must set a PIN before continuing."
      end
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
