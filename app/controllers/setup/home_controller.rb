# frozen_string_literal: true

module Setup
  class HomeController < BaseController
    skip_before_action :require_setup_access, only: :locked_out

    def show
    end

    def locked_out
    end
  end
end
