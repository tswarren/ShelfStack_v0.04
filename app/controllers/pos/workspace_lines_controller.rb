# frozen_string_literal: true

module Pos
  class WorkspaceLinesController < BaseController
    before_action -> { authorize_pos!("pos.returns.receipted") }, only: :add_return_line
    before_action -> { authorize_pos!("pos.fulfill_customer_reservation") }, only: :add_reservation_line

    def add_return_line
      transaction = ensure_workspace_draft!
      return if performed?

      Pos::AddReturnLine.call!(
        transaction: transaction,
        store: pos_store,
        params: params
      )
      redirect_to edit_pos_transaction_path(transaction, mode: "sale"), notice: "Return line added."
    rescue Pos::AddReturnLine::Error => e
      redirect_to pos_root_path, alert: e.message
    end

    def add_reservation_line
      transaction = ensure_workspace_draft!
      return if performed?

      reservation = InventoryReservation.find(params[:inventory_reservation_id])
      quantity = params[:quantity].presence&.to_i
      quantity = 1 if quantity.nil? || quantity <= 0

      Pos::AddReservationLine.call!(
        transaction: transaction,
        reservation: reservation,
        added_by_user: current_user,
        quantity: quantity
      )
      redirect_to edit_pos_transaction_path(transaction, mode: "sale"), notice: "Pickup line added."
    rescue ActiveRecord::RecordNotFound
      redirect_to pos_root_path, alert: "Reservation not found."
    rescue Pos::AddReservationLine::Error => e
      redirect_to pos_root_path, alert: e.message
    end

    private

    def ensure_workspace_draft!
      result = DraftCreator.call(
        store: pos_store,
        workstation: current_workstation,
        cashier_user: current_user,
        register_session: current_register_session,
        user_session: Current.user_session
      )

      case result.status
      when :legacy_found
        redirect_to pos_root_path, alert: "An older draft needs review before adding items."
        nil
      when :conflict
        redirect_to pos_root_path, alert: "Multiple active drafts exist. Resolve the conflict before adding items."
        nil
      when :missing_register_session, :invalid_register_session
        redirect_to pos_root_path, alert: "Open the register before adding items."
        nil
      when :created, :resumed
        result.transaction
      else
        redirect_to pos_root_path, alert: "Unable to start transaction."
        nil
      end
    end
  end
end
