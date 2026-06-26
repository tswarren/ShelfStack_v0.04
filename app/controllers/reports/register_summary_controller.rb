# frozen_string_literal: true

module Reports
  class RegisterSummaryController < BaseController
    before_action -> { authorize_report!("pos.reports.register_summary") }

    def show
      @sessions = PosRegisterSession.where(store: report_store).order(opened_at: :desc).limit(50)
      session_id = params[:register_session_id].presence || current_register_session&.id
      @scope = Pos::ReportScope.from_params(
        store: report_store,
        params: { register_session_id: session_id }
      )
      @report = @scope && Pos::SalesRegisterSummaryReport.call(scope: @scope)
    end
  end
end
