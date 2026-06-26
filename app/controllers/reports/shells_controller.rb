# frozen_string_literal: true

module Reports
  class ShellsController < ApplicationController
    before_action :require_active_session
    before_action -> { authorize!("reports.foundation.view") }

    def reconciliation
      @presenter = Shells::ReconciliationPresenter.new(
        start_date: params[:start_date],
        end_date: params[:end_date]
      )
    end

    def queue
      @presenter = Shells::QueuePresenter.new(
        empty: ActiveModel::Type::Boolean.new.cast(params[:empty]),
        status: params[:status]
      )
    end
  end
end
