# frozen_string_literal: true

module Customers
  class HomeController < ApplicationController
    before_action :require_active_session

    def show
      if Authorization.allowed?(user: current_user, permission_key: "customers.access", store: current_store)
        redirect_to customers_customers_path
      else
        redirect_to customers_locked_out_path
      end
    end

    def locked_out
      render layout: "application"
    end
  end
end
