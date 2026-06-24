# frozen_string_literal: true

module Buybacks
  class BaseController < ApplicationController
    before_action :require_active_session
    before_action :require_buybacks_access

    layout "application"

    helper BuybacksHelper
    helper_method :buybacks_store, :current_register_session

    private

    def require_buybacks_access
      return if Authorization.allowed?(user: current_user, permission_key: "buybacks.view", store: current_store)

      redirect_to buybacks_locked_out_path, alert: "You do not have buybacks access."
    end

    def authorize_buyback!(permission_key)
      return true if Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)

      redirect_to buybacks_root_path, alert: "You are not authorized for this action."
      false
    end

    def buybacks_store
      current_store
    end

    def current_register_session
      return @current_register_session if defined?(@current_register_session)

      @current_register_session = current_workstation && PosRegisterSession.open_for_workstation(current_workstation)
    end

    def set_session
      @buyback_session = BuybackSession.for_store(buybacks_store).find(params[:id])
    end
  end
end
