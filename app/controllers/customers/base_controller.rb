# frozen_string_literal: true

module Customers
  class BaseController < ApplicationController
    before_action :require_active_session
    before_action :require_customers_access

    layout "application"

    helper CustomersHelper
    helper_method :customers_store

    private

    def require_customers_access
      return if Authorization.allowed?(user: current_user, permission_key: "customers.access", store: current_store)

      redirect_to customers_locked_out_path, alert: "You do not have customers access."
    end

    def authorize!(permission_key)
      return if Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)

      redirect_back fallback_location: customers_root_path, alert: "You are not authorized for this action."
    end

    def record_audit!(event_name, auditable, details: {})
      AuditEvents.record!(
        actor: current_user,
        event_name: event_name,
        auditable: auditable,
        details: AuditEvents.build_details(auditable: auditable, event_name: event_name, extra: details)
      )
    end

    def customers_store
      current_store
    end
  end
end
