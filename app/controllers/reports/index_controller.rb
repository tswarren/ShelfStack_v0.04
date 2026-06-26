# frozen_string_literal: true

module Reports
  class IndexController < BaseController
    def show
      @grouped_reports = Registry.grouped_for(user: current_user, store: current_store)
      return if @grouped_reports.any?

      redirect_to root_path, alert: "You do not have access to any reports."
    end
  end
end
