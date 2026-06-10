# frozen_string_literal: true

module Setup
  class BaseController < ApplicationController
    before_action :require_active_session
    before_action :require_setup_access

    layout "application"

    private

    def require_setup_access
      return if Authorization.allowed?(user: current_user, permission_key: "setup.access", store: current_store)

      redirect_to setup_locked_out_path, alert: "You do not have setup access."
    end

    def record_audit!(event_name, auditable, details: {})
      AuditEvents.record!(actor: current_user, event_name: event_name, auditable: auditable, details: details)
    end
  end
end
