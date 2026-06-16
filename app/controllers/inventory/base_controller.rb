# frozen_string_literal: true

module Inventory
  class BaseController < ApplicationController
    before_action :require_active_session
    before_action :require_inventory_access

    layout "application"

    helper_method :inventory_store

    private

    def require_inventory_access
      return if Authorization.allowed?(user: current_user, permission_key: "inventory.access", store: current_store)

      redirect_to inventory_locked_out_path, alert: "You do not have inventory access."
    end

    def record_audit!(event_name, auditable, details: {})
      AuditEvents.record!(
        actor: current_user,
        event_name: event_name,
        auditable: auditable,
        details: AuditEvents.build_details(auditable: auditable, event_name: event_name, extra: details)
      )
    end

    def inventory_store
      current_store
    end
  end
end
