# frozen_string_literal: true

module Pos
  class RegisterSessionsController < BaseController
    before_action -> { authorize_pos!("pos.register_sessions.view") }, only: %i[show]
    before_action -> { authorize_pos!("pos.register_sessions.open") }, only: %i[new create]
    before_action -> { authorize_pos!("pos.register_sessions.close") }, only: %i[close]
    before_action -> { authorize_pos!("pos.register_sessions.force_close") }, only: %i[force_close]
    before_action :set_register_session, only: %i[show close force_close]

    def new
      redirect_to pos_root_path, alert: "Register session already open." if current_register_session
    end

    def create
      authorize_pos!("pos.register_sessions.open")
      session = Pos::RegisterSessionLifecycle.open!(
        store: pos_store,
        workstation: current_workstation,
        opened_by_user: current_user,
        business_date: params[:business_date].presence || Date.current,
        opening_cash_cents: parse_dollar_param(params[:opening_cash_dollars]) || params[:opening_cash_cents].to_i,
        notes: params[:notes]
      )
      redirect_to pos_register_session_path(session), notice: "Register session opened."
    rescue Pos::RegisterSessionLifecycle::Error => e
      redirect_to new_pos_register_session_path, alert: e.message
    end

    def show
      @summary = Pos::RegisterSessionSummary.for(@register_session)
      @completed_transactions = @register_session.pos_transactions.completed_records.order(completed_at: :desc).limit(50)
      @cash_movements = @register_session.pos_cash_movements.order(recorded_at: :desc)
    end

    def close
      expected = Pos::RegisterSessionSummary.for(@register_session).expected_closing_cash_cents
      counted = parse_dollar_param(params[:counted_closing_cash_dollars]) || params[:counted_closing_cash_cents].to_i

      Pos::RegisterSessionLifecycle.close!(
        session: @register_session,
        closed_by_user: current_user,
        expected_closing_cash_cents: expected,
        counted_closing_cash_cents: counted,
        force: false
      )
      redirect_to pos_root_path, notice: "Register session closed."
    rescue Pos::RegisterSessionLifecycle::Error => e
      redirect_to pos_register_session_path(@register_session), alert: e.message
    end

    def force_close
      unless authorized_force_close?
        redirect_to pos_register_session_path(@register_session), alert: "Supervisor authorization required to force close."
        return
      end

      suspended_count = PosTransaction.suspended.where(workstation: @register_session.workstation).count
      flash[:warning] = "#{suspended_count} suspended transaction(s) remain on this workstation." if suspended_count.positive?

      expected = Pos::RegisterSessionSummary.for(@register_session).expected_closing_cash_cents
      counted = parse_dollar_param(params[:counted_closing_cash_dollars]) || params[:counted_closing_cash_cents].to_i

      Pos::RegisterSessionLifecycle.close!(
        session: @register_session,
        closed_by_user: current_user,
        expected_closing_cash_cents: expected,
        counted_closing_cash_cents: counted,
        force: true
      )
      redirect_to pos_root_path, notice: "Register session force-closed."
    rescue Pos::RegisterSessionLifecycle::Error => e
      redirect_to pos_register_session_path(@register_session), alert: e.message
    end

    private

    def set_register_session
      @register_session = PosRegisterSession.where(store: pos_store).find(params[:id])
    end

    def authorized_force_close?
      authorization = PosAuthorization.find_by(id: params[:pos_authorization_id])
      Pos::AuthorizationRequest.valid_for?(
        authorization: authorization,
        authorization_type: "force_close_register",
        pos_register_session: @register_session
      )
    end
  end
end
