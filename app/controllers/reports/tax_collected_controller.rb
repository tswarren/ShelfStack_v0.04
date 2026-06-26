# frozen_string_literal: true

module Reports
  class TaxCollectedController < BaseController
    include Reports::PosScopeReporting

    before_action -> { authorize_report!("pos.reports.summary") }
    before_action :load_pos_scope_report!, only: :show

    def show
      @report = @scope && TaxCollected::Query.call(scope: @scope)
    end
  end
end
