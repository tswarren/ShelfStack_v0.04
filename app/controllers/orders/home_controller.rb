# frozen_string_literal: true

module Orders
  class HomeController < BaseController
    skip_before_action :require_orders_access, only: :locked_out

    def show
    end

    def locked_out
    end
  end
end
