# frozen_string_literal: true

module Pos
  class AuthorizationsController < BaseController
    before_action -> { authorize_pos!("pos.access") }

    def create
      authorization = Pos::AuthorizationRequest.grant!(
        authorization_type: params[:authorization_type],
        requested_by: current_user,
        manager_username: params[:manager_username],
        manager_pin: params[:manager_pin],
        store: pos_store,
        pos_transaction: load_transaction,
        pos_register_session: load_register_session,
        details: { "requested_from" => "pos_ui" }
      )

      render json: { authorization_id: authorization.id, authorization_type: authorization.authorization_type }
    rescue Pos::AuthorizationRequest::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def load_transaction
      return if params[:pos_transaction_id].blank?

      PosTransaction.where(store: pos_store).find(params[:pos_transaction_id])
    end

    def load_register_session
      return if params[:pos_register_session_id].blank?

      PosRegisterSession.where(store: pos_store).find(params[:pos_register_session_id])
    end
  end
end
