# frozen_string_literal: true

module Reports
  module PosScopeReporting
    extend ActiveSupport::Concern

    included do
      helper_method :summary_filter_params, :pos_report_sessions
    end

    private

    def summary_filter_params
      params.permit(:filter_type, :register_session_id, :business_date, :start_date, :end_date)
    end

    def load_pos_scope_report!
      @sessions = PosRegisterSession.where(store: report_store).order(opened_at: :desc).limit(50)
      @scope = Pos::ReportScope.from_params(store: report_store, params: summary_filter_params)
    end

    def pos_report_sessions
      @sessions || PosRegisterSession.where(store: report_store).order(opened_at: :desc).limit(50)
    end
  end
end
