# frozen_string_literal: true

module Sourcing
  class BaseController < ApplicationController
    before_action :require_active_session
    before_action :require_sourcing_access

    layout "application"

    helper SourcingHelper
    helper_method :sourcing_store

    private

    def require_sourcing_access
      return if Authorization.allowed?(user: current_user, permission_key: "sourcing.access", store: current_store)

      redirect_to sourcing_locked_out_path, alert: "You do not have sourcing workspace access."
    end

    def authorize_sourcing!(permission_key)
      return true if Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)

      redirect_back fallback_location: sourcing_root_path, alert: "You are not authorized for this action."
      false
    end

    def sourcing_store
      current_store
    end

    def set_sourcing_run
      run_id = params[:run_id] || params[:id]
      @sourcing_run = SourcingRun.where(store: sourcing_store).find(run_id)
    end

    def set_sourcing_attempt
      @sourcing_attempt = SourcingAttempt.joins(:sourcing_run)
                                         .where(sourcing_runs: { store_id: sourcing_store.id })
                                         .find(params[:id])
    end
  end
end
