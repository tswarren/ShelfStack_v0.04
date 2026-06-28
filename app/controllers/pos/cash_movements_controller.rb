# frozen_string_literal: true

module Pos
  class CashMovementsController < BaseController
    before_action -> { authorize_pos!("pos.cash_movements.create") }

    def create
      session = PosRegisterSession.where(store: pos_store).find(params[:register_session_id])
      movement = session.pos_cash_movements.create!(
        store: pos_store,
        movement_type: params[:movement_type],
        amount_cents: parse_dollar_param(params[:amount_dollars]) || params[:amount_cents].to_i,
        reason_code: params[:reason_code],
        notes: params[:notes],
        recorded_by_user: current_user,
        recorded_at: Time.current
      )

      record_audit!("pos.cash_movement.recorded", movement)
      redirect_to safe_return_path(session), notice: "Cash movement recorded."
    end

    private

    def safe_return_path(session)
      path = params[:return_path].to_s
      return pos_register_session_path(session) unless path.start_with?("/pos")

      path
    end
  end
end
