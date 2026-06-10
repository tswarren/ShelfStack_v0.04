# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :store, :workstation, :user_session, :workstation_assignment, :time_zone

  def time_zone
    super || store&.time_zone || Rails.application.config.time_zone
  end
end
