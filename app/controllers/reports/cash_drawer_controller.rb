# frozen_string_literal: true

module Reports
  class CashDrawerController < BaseController
    before_action -> { authorize_report!("pos.reports.drawer") }

    def show
      @sessions = PosRegisterSession.where(store: report_store).order(opened_at: :desc).limit(20)
      @session = if params[:session_id].present?
        PosRegisterSession.where(store: report_store).find_by(id: params[:session_id])
      else
        current_register_session
      end
      @summary = @session && Pos::RegisterSessionSummary.for(@session)
    end
  end
end
