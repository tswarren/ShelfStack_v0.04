# frozen_string_literal: true

class PinsController < ApplicationController
  before_action :require_active_session

  def edit
  end

  def update
    user = current_user
    pin = params[:pin].to_s
    pin_confirmation = params[:pin_confirmation].to_s

    if pin.blank?
      flash.now[:alert] = "PIN can't be blank."
      render :edit, status: :unprocessable_entity
      return
    end

    if pin_confirmation.blank?
      flash.now[:alert] = "PIN confirmation can't be blank."
      render :edit, status: :unprocessable_entity
      return
    end

    if pin != pin_confirmation
      flash.now[:alert] = "PIN confirmation does not match."
      render :edit, status: :unprocessable_entity
      return
    end

    user.pin = pin

    if user.save
      AuditEvents.record!(actor: user, event_name: "user.pin_changed", auditable: user)
      redirect_to root_path, notice: "PIN updated successfully."
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
