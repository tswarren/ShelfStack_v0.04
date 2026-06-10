# frozen_string_literal: true

class SessionStatusController < ApplicationController
  def show
    session = current_user_session
    render json: {
      status: session&.status || "none",
      locked: session&.locked? || false,
      terminal: session&.terminal? || false
    }
  end
end
