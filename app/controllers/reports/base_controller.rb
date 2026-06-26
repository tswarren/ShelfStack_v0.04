# frozen_string_literal: true

module Reports
  class BaseController < ApplicationController
    before_action :require_active_session
    around_action :use_store_time_zone

    layout "application"

    helper PosHelper
    helper PosReportsHelper
    helper CustomersHelper

    helper_method :report_store, :current_register_session

    private

    def report_store
      current_store
    end

    def authorize_report!(permission_key)
      return if Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)

      redirect_to root_path, alert: "You are not authorized to view that report."
    end

    def use_store_time_zone
      Time.use_zone(current_store&.time_zone || "UTC") { yield }
    end

    def current_register_session
      return @current_register_session if defined?(@current_register_session)

      @current_register_session = current_workstation && PosRegisterSession.open_for_workstation(current_workstation)
    end
  end
end
