# frozen_string_literal: true

module Buybacks
  class SessionsController < BaseController
    before_action :set_session, only: %i[
      show update complete cancel void receipt save_proposal open_decision print_proposal
      accept_all_lines decline_all_lines donate_declined_lines
    ]
    before_action :require_create_permission!, only: %i[new create]
    before_action :require_update_permission!, only: %i[update]
    before_action :require_save_proposal_permission!, only: %i[save_proposal]
    before_action :require_print_proposal_permission!, only: %i[print_proposal]
    before_action :require_printable_proposal!, only: %i[print_proposal]
    before_action :require_batch_decision_permission!,
                    only: %i[accept_all_lines decline_all_lines donate_declined_lines open_decision]
    before_action :require_complete_permission!, only: :complete
    before_action :require_cancel_permission!, only: :cancel
    before_action :require_void_permission!, only: :void

    def new
      @buyback_session = BuybackSession.new
      @customers = Customer.active_records.order(:display_name)
    end

    def create
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
      @proposal = ProposalBuilder.build(@buyback_session) if @buyback_session.quoted? || @buyback_session.decision?
      @decision_totals = DecisionTotalsBuilder.build(@buyback_session) if @buyback_session.decision?
      @receipt = ReceiptBuilder.build(@buyback_session) if @buyback_session.completed?
      @seller_requirements = SellerRequirements.check(customer: @buyback_session.customer)
      @seller_checklist = SellerRequirements.checklist(customer: @buyback_session.customer)
      @workflow = SessionWorkflowPresenter.new(
        session: @buyback_session,
        lines: @lines,
        proposal: @proposal,
        decision_totals: @decision_totals,
        seller_requirements: @seller_requirements,
        register_session: current_register_session
      )
    end

    def update
      if @buyback_session.editable?
        @buyback_session.update!(session_params)
        @buyback_session.update!(payout_selected_at: Time.current) if session_params[:payout_mode].present?
      end
      redirect_to buybacks_session_path(@buyback_session), notice: "Session updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def save_proposal
      @buyback_session.update!(workstation: current_workstation) if @buyback_session.workstation.blank?
      SaveProposal.call!(session: @buyback_session, actor: current_user)
      respond_to_buyback_session_update(notice: "Proposal saved.")
    rescue Buybacks::SaveProposal::Error => e
      respond_to_buyback_session_update(alert: e.message)
    end

    def open_decision
      OpenCustomerDecision.call!(session: @buyback_session, actor: current_user)
      respond_to_buyback_session_update(notice: "Customer decision stage opened.")
    rescue Buybacks::OpenCustomerDecision::Error => e
      respond_to_buyback_session_update(alert: e.message)
    end

    def print_proposal
      @proposal = ProposalBuilder.build(@buyback_session)
      @buyback_session.update!(proposal_printed_at: Time.current)
      AuditEvents.record!(actor: current_user, event_name: "buyback.proposal.printed", auditable: @buyback_session)
      render layout: "print"
    end

    def accept_all_lines
      AcceptAllLines.call!(session: @buyback_session, actor: current_user)
      respond_to_buyback_session_update(notice: "All lines accepted by customer.")
    rescue Buybacks::RecordCustomerDecision::Error => e
      respond_to_buyback_session_update(alert: e.message)
    end

    def decline_all_lines
      DeclineAllLines.call!(session: @buyback_session, actor: current_user)
      respond_to_buyback_session_update(notice: "All lines declined by customer.")
    rescue Buybacks::RecordCustomerDecision::Error => e
      respond_to_buyback_session_update(alert: e.message)
    end

    def donate_declined_lines
      DonateDeclinedLines.call!(session: @buyback_session, actor: current_user)
      respond_to_buyback_session_update(notice: "Declined lines marked as donated.")
    rescue Buybacks::RecordCustomerDecision::Error => e
      respond_to_buyback_session_update(alert: e.message)
    end

    def complete
      payout_permission = case @buyback_session.payout_mode
      when "cash" then "buybacks.pay_cash"
      when "trade_credit" then "buybacks.pay_trade_credit"
      when "no_value_donation" then "buybacks.accept_donation"
      else nil
      end
      return unless authorize_buyback!(payout_permission) if payout_permission.present?

      @buyback_session.update!(workstation: current_workstation) if @buyback_session.workstation.blank?
      CompleteSession.call!(
        session: @buyback_session,
        actor: current_user,
        register_session: current_register_session
      )
      if @buyback_session.payout_mode == "trade_credit"
        redirect_to trade_credit_slip_buybacks_session_path(@buyback_session), notice: "Buyback completed."
      else
        redirect_to receipt_buybacks_session_path(@buyback_session), notice: "Buyback completed."
      end
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

    def require_create_permission!
      authorize_buyback!("buybacks.create")
    end

    def require_update_permission!
      authorize_buyback!("buybacks.update")
    end

    def require_save_proposal_permission!
      authorize_buyback!("buybacks.proposal.save")
    end

    def require_print_proposal_permission!
      authorize_buyback!("buybacks.proposal.print")
    end

    def require_printable_proposal!
      return if @buyback_session.buyback_number.present? &&
                @buyback_session.status.in?(%w[quoted decision completed])

      redirect_to buybacks_session_path(@buyback_session),
                  alert: "Proposal printing is available after the proposal is saved."
    end

    def require_batch_decision_permission!
      authorize_buyback!("buybacks.decisions.batch_update")
    end

    def require_complete_permission!
      authorize_buyback!("buybacks.complete")
    end

    def require_cancel_permission!
      authorize_buyback!("buybacks.cancel")
    end

    def require_void_permission!
      authorize_buyback!("buybacks.void")
    end
  end
end
