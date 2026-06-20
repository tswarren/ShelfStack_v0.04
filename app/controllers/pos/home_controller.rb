# frozen_string_literal: true

module Pos
  class HomeController < BaseController
    def show
      session = current_register_session
      @register_session = session && PosRegisterSession.includes(:opened_by_user).find(session.id)
      @draft_transactions = []
      @suspended_transactions = []
      @session_summary = @register_session && Pos::RegisterSessionSummary.for(@register_session)
      return unless current_workstation

      @draft_transactions = PosTransaction.drafts
        .includes(:pos_transaction_lines, :cashier_user)
        .where(store: pos_store, workstation: current_workstation, cashier_user: current_user)
        .order(updated_at: :desc)
      @suspended_transactions = PosTransaction.suspended
        .includes(:pos_transaction_lines, :cashier_user)
        .where(store: pos_store, workstation: current_workstation)
        .order(suspended_at: :desc)
    end

    def locked_out
      render :locked_out
    end
  end
end
