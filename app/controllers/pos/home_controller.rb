# frozen_string_literal: true

module Pos
  class HomeController < BaseController
    def show
      @register_session = current_register_session
      @draft_transactions = PosTransaction.drafts.where(store: pos_store, workstation: current_workstation, cashier_user: current_user)
      @suspended_transactions = PosTransaction.suspended.where(store: pos_store, workstation: current_workstation)
    end

    def locked_out
      render :locked_out
    end
  end
end
