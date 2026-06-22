# frozen_string_literal: true

module Pos
  class BaseController < ApplicationController
    before_action :require_active_session
    before_action :require_pos_access
    around_action :use_store_time_zone

    layout "pos"

    helper PosHelper
    helper PosReportsHelper
    helper_method :pos_store, :current_register_session, :pos_mode, :pos_workspace_mode, :pos_pickup_mode?

    private

    def require_pos_access
      return if Authorization.allowed?(user: current_user, permission_key: "pos.access", store: current_store)

      redirect_to pos_locked_out_path, alert: "You do not have POS access."
    end

    def authorize_pos!(permission_key)
      return if Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)

      redirect_to pos_root_path, alert: "You are not authorized to perform that action."
    end

    def current_register_session
      return @current_register_session if defined?(@current_register_session)

      @current_register_session = current_workstation && PosRegisterSession.open_for_workstation(current_workstation)
    end

    def pos_store
      current_store
    end

    def pos_mode
      mode = params[:mode].presence || "sale"
      return "return" if mode == "return"
      return "sale" if mode == "pickup"

      PosHelper::POS_MODES.include?(mode) ? mode : "sale"
    end

    def pos_workspace_mode
      mode = params[:mode].presence || "sale"
      PosHelper::POS_WORKSPACE_MODES.include?(mode) ? mode : "sale"
    end

    def pos_pickup_mode?
      pos_workspace_mode == "pickup"
    end

    def parse_dollar_param(value)
      return nil if value.blank?

      (BigDecimal(value.to_s) * 100).round.to_i
    end

    def use_store_time_zone
      Time.use_zone(Current.time_zone) { yield }
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
