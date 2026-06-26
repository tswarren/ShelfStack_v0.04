# frozen_string_literal: true

module Reports
  class DiscountSummaryController < BaseController
    include Reports::PosScopeReporting

    before_action -> { authorize_report!("pos.reports.summary") }
    before_action :load_pos_scope_report!, only: :show

    def show
      @report = @scope && DiscountSummary::Query.call(scope: @scope)
    end
  end
end
