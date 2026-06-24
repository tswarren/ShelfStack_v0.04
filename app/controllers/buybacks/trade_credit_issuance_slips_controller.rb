# frozen_string_literal: true

module Buybacks
  class TradeCreditIssuanceSlipsController < BaseController
    before_action :set_session
    before_action -> { authorize_buyback!("buybacks.trade_credit_slip.print") }, only: :print

    def show
      verify_trade_credit_session!
      @presenter = TradeCreditIssuanceSlipPresenter.new(
        session: @buyback_session,
        ledger_entry: @buyback_session.stored_value_ledger_entry,
        actor: current_user
      )
      record_slip_audit!("buyback.trade_credit_slip.printed") unless slip_already_viewed?
      session[:buyback_slip_viewed] ||= {}
      session[:buyback_slip_viewed][@buyback_session.id.to_s] = true
    end

    def print
      verify_trade_credit_session!
      record_slip_audit!("buyback.trade_credit_slip.reprinted")

      respond_to do |format|
        format.html { redirect_to trade_credit_slip_buybacks_session_path(@buyback_session) }
        format.turbo_stream { head :no_content }
      end
    end

    private

    def verify_trade_credit_session!
      unless @buyback_session.completed? &&
          @buyback_session.payout_mode == "trade_credit" &&
          @buyback_session.stored_value_ledger_entry.present?
        raise ActiveRecord::RecordNotFound
      end
    end

    def record_slip_audit!(event_name)
      AuditEvents.record!(
        actor: current_user,
        event_name: event_name,
        auditable: @buyback_session,
        source: @buyback_session.stored_value_ledger_entry
      )
    end

    def slip_already_viewed?
      session[:buyback_slip_viewed]&.key?(@buyback_session.id.to_s)
    end
  end
end
