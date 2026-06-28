# frozen_string_literal: true

module Pos
  class WorkspaceSalesController < BaseController
    def create
      return unless authorize_pos_json!("pos.transactions.create")
      return unless authorize_pos_json!("pos.transactions.update") if params[:customer_id].present?

      customer = resolve_customer
      return if performed?

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
        result.transaction.update!(customer: customer) if customer
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

    def resolve_customer
      return if params[:customer_id].blank?

      Customer.active_records.find(params[:customer_id])
    rescue ActiveRecord::RecordNotFound
      render json: { action: "message", payload: {}, message: "Customer could not be found." }, status: :unprocessable_entity
      nil
    end

    def authorize_pos_json!(permission_key)
      return true if Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)

      render json: {
        action: "message",
        payload: {},
        message: "You are not authorized to perform that action."
      }, status: :forbidden
      false
    end
  end
end
