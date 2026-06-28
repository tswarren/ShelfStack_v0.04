# frozen_string_literal: true

module Pos
  class WorkspaceLinesController < BaseController
    before_action -> { authorize_pos!("pos.returns.receipted") }, only: :add_return_line
    before_action -> { authorize_pos!("pos.returns.no_receipt") }, only: :add_no_receipt_line
    before_action -> { authorize_pos!("pos.lines.add") }, only: :add_no_receipt_line
    before_action :authorize_no_receipt_return_line!, only: :add_open_ring_line
    before_action -> { authorize_pos!("pos.lines.add.open_ring") }, only: :add_open_ring_line
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

    def add_no_receipt_line
      transaction = ensure_workspace_draft!
      return if performed?

      variant = ProductVariant.find(params[:product_variant_id])
      Pos::AddVariantLine.call!(
        transaction: transaction,
        variant: variant,
        quantity: params[:quantity].presence || -1,
        unit_price_cents: parse_dollar_param(params[:unit_price]),
        entry_action: "return_no_receipt"
      )
      redirect_to edit_pos_transaction_path(transaction, mode: "sale"), notice: "Return line added."
    rescue ActiveRecord::RecordNotFound
      redirect_to pos_root_path, alert: "Item could not be found."
    rescue AddVariantLine::Error, ActiveRecord::RecordInvalid => e
      redirect_to pos_root_path, alert: e.message.presence || "Unable to add return line."
    end

    def add_open_ring_line
      transaction = ensure_workspace_draft!
      return if performed?

      Pos::AddOpenRingLine.call!(
        transaction: transaction,
        store: pos_store,
        register_session: current_register_session,
        params: params
      )
      redirect_to edit_pos_transaction_path(transaction, mode: "sale"), notice: "Open-ring line added."
    rescue Pos::AddOpenRingLine::Error => e
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
