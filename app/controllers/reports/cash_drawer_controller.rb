# frozen_string_literal: true

module Reports
  class CashDrawerController < BaseController
    before_action -> { authorize_report!("pos.reports.drawer") }

    def show
      @sessions = PosRegisterSession.where(store: report_store).order(opened_at: :desc).limit(20)
      session_id = params[:session_id].presence || params[:register_session_id].presence
      @session = if session_id.present?
        PosRegisterSession.where(store: report_store).find_by(id: session_id)
      else
        current_register_session
      end
      @summary = @session && Pos::RegisterSessionSummary.for(@session)
    end
  end
end
