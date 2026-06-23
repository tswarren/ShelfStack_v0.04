# frozen_string_literal: true

module Buybacks
  class HomeController < BaseController
    skip_before_action :require_buybacks_access, only: :locked_out

    def show
      @sessions = BuybackSession.for_store(buybacks_store).order(created_at: :desc).limit(25)
      @summary = ReportBuilder.summary(store: buybacks_store)
    end

    def locked_out
      render layout: "application"
    end
  end
end
