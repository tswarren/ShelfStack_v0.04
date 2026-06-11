# frozen_string_literal: true

module Items
  class BaseController < ApplicationController
    before_action :require_active_session
    before_action :require_items_access

    layout "application"

    private

    def require_items_access
      return if Authorization.allowed?(user: current_user, permission_key: "items.access", store: current_store)

      redirect_to items_locked_out_path, alert: "You do not have items access."
    end

    def record_audit!(event_name, auditable, details: {})
      AuditEvents.record!(
        actor: current_user,
        event_name: event_name,
        auditable: auditable,
        details: AuditEvents.build_details(auditable: auditable, event_name: event_name, extra: details)
      )
    end
  end
end
