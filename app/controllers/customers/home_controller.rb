# frozen_string_literal: true

module Customers
  class HomeController < BaseController
    skip_before_action :require_customers_access, only: :locked_out

    def show
      @dashboard = DashboardPresenter.new(store: customers_store)
    end

    def locked_out
      render layout: "application"
    end
  end
end
