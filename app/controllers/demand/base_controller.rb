# frozen_string_literal: true

module Demand
  class BaseController < ApplicationController
    before_action :require_active_session
    before_action :require_demand_access

    layout "application"

    helper DemandHelper
    helper_method :demand_store

    private

    def require_demand_access
      return if Authorization.allowed?(user: current_user, permission_key: "demand.access", store: current_store)

      redirect_to demand_locked_out_path, alert: "You do not have demand workspace access."
    end

    def authorize_demand!(permission_key)
      return true if Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)

      redirect_back fallback_location: demand_root_path, alert: "You are not authorized for this action."
      false
    end

    def demand_store
      current_store
    end

    def set_demand_line
      @demand_line = DemandLine.where(store: demand_store).find(params[:id])
    end

    def set_stock_consideration
      @stock_consideration = StockConsideration.where(store: demand_store).find(params[:id])
    end
  end
end
