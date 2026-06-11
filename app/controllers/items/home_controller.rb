# frozen_string_literal: true

module Items
  class HomeController < BaseController
    skip_before_action :require_items_access, only: :locked_out

    def show
    end

    def locked_out
    end
  end
end
