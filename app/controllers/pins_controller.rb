# frozen_string_literal: true

class PinsController < ApplicationController
  before_action :require_active_session

  def edit
  end

  def update
    user = current_user
    user.pin = params[:pin]

    if user.save
      AuditEvents.record!(actor: user, event_name: "user.pin_changed", auditable: user)
      redirect_to root_path, notice: "PIN updated successfully."
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
