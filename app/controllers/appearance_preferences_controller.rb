# frozen_string_literal: true

class AppearancePreferencesController < ApplicationController
  before_action :require_active_session

  def update
    if current_user.update(appearance_preference_params)
      redirect_back fallback_location: root_path, notice: "Appearance updated."
    else
      redirect_back fallback_location: root_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  private

  def appearance_preference_params
    params.permit(:appearance_view_mode, :appearance_color_mode).compact_blank
  end
end
