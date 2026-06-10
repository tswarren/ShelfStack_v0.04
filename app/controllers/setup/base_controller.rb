# frozen_string_literal: true

module Setup
  class BaseController < ApplicationController
    before_action :require_active_session
    before_action :require_setup_access

    layout "application"

    private

    def require_setup_access
      authorize!("setup.access")
    end

    def record_audit!(event_name, auditable, details: {})
      AuditEvents.record!(actor: current_user, event_name: event_name, auditable: auditable, details: details)
    end
  end
end
