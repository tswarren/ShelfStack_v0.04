# frozen_string_literal: true

module Buybacks
  class SessionsController < BaseController
    before_action :set_session, only: %i[show update complete cancel void receipt]
    before_action -> { authorize_buyback!("buybacks.create") }, only: %i[new create]
    before_action -> { authorize_buyback!("buybacks.update") }, only: %i[update]
    before_action -> { authorize_buyback!("buybacks.complete") }, only: :complete
    before_action -> { authorize_buyback!("buybacks.cancel") }, only: :cancel
    before_action -> { authorize_buyback!("buybacks.void") }, only: :void

    def new
      @buyback_session = BuybackSession.new
      @customers = Customer.active_records.order(:display_name)
    end

    def create
      authorize_buyback!("buybacks.create")
      customer = Customer.find(params[:customer_id])
      session = StartSession.call!(
        store: buybacks_store,
        customer: customer,
        actor: current_user,
        workstation: current_workstation,
        notes: params[:notes]
      )
      redirect_to buybacks_session_path(session), notice: "Buyback session started."
    rescue ArgumentError => e
      redirect_to new_buybacks_session_path, alert: e.message
    end

    def show
      @lines = @buyback_session.buyback_lines.order(:line_number)
      @conditions = ProductCondition.buyback_eligible.order(:buyback_sort_order, :sort_order)
      @sub_departments = SubDepartment.active_records.where(buyback_allowed: true).order(:name)
      @reject_reasons = BuybackRejectReason.active_records.order(:sort_order)
      @receipt = ReceiptBuilder.build(@buyback_session) if @buyback_session.completed?
    end

    def update
      if @buyback_session.editable?
        @buyback_session.update!(session_params)
      end
      redirect_to buybacks_session_path(@buyback_session), notice: "Session updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def complete
      payout_permission = case @buyback_session.payout_mode
      when "cash" then "buybacks.pay_cash"
      when "trade_credit" then "buybacks.pay_trade_credit"
      when "no_value_donation" then "buybacks.accept_donation"
      else nil
      end
      authorize_buyback!(payout_permission) if payout_permission.present?

      @buyback_session.update!(workstation: current_workstation) if @buyback_session.workstation.blank?
      CompleteSession.call!(
        session: @buyback_session,
        actor: current_user,
        register_session: current_register_session
      )
      redirect_to receipt_buybacks_session_path(@buyback_session), notice: "Buyback completed."
    rescue Buybacks::CompleteSession::Error, Buybacks::SellerRequirements::Error => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def cancel
      CancelSession.call!(session: @buyback_session, actor: current_user)
      redirect_to buybacks_root_path, notice: "Buyback cancelled."
    rescue ArgumentError => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def void
      authorization = PosAuthorization.find_by(id: params[:pos_authorization_id])
      VoidSession.call!(
        session: @buyback_session,
        actor: current_user,
        register_session: current_register_session,
        void_reason: params[:void_reason],
        pos_authorization: authorization,
        notes: params[:notes]
      )
      redirect_to buybacks_session_path(@buyback_session), notice: "Buyback voided."
    rescue Buybacks::VoidSession::Error => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def receipt
      @receipt = ReceiptBuilder.build(@buyback_session)
      render layout: "application"
    end

    private

    def session_params
      params.require(:buyback_session).permit(
        :payout_mode, :needs_label, :needs_review, :needs_cleaning,
        :hold_for_review, :processing_notes, :notes
      )
    end
  end
end
