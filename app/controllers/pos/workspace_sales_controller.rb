# frozen_string_literal: true

module Pos
  class WorkspaceSalesController < BaseController
    before_action -> { authorize_pos!("pos.transactions.create") }

    def create
      result = Pos::DraftCreator.call(
        store: pos_store,
        workstation: current_workstation,
        cashier_user: current_user,
        register_session: current_register_session,
        user_session: Current.user_session
      )

      case result.status
      when :legacy_found
        render json: { action: "message", payload: {}, message: "An older draft needs review before starting a sale." }, status: :unprocessable_entity
      when :conflict
        render json: { action: "message", payload: {}, message: "Multiple active drafts exist. Resolve the conflict before starting a sale." }, status: :unprocessable_entity
      when :missing_register_session, :invalid_register_session
        render json: { action: "message", payload: {}, message: "Open the register before starting a sale." }, status: :unprocessable_entity
      when :created, :resumed
        attach_customer!(result.transaction) if params[:customer_id].present?
        render json: {
          action: "redirect",
          payload: { url: edit_pos_transaction_path(result.transaction) },
          message: nil
        }
      else
        render json: { action: "message", payload: {}, message: "Unable to start sale." }, status: :unprocessable_entity
      end
    end

    private

    def attach_customer!(transaction)
      customer = Customer.find(params[:customer_id])
      transaction.update!(customer: customer)
    end
  end
end
