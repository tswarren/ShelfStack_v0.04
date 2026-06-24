# frozen_string_literal: true

module Buybacks
  module SessionStreamRendering
    extend ActiveSupport::Concern

    private

    def prepare_buyback_session_view!(session)
      @buyback_session = session.reload
      @lines = @buyback_session.buyback_lines.order(:line_number)
      @conditions = ProductCondition.buyback_eligible.order(:buyback_sort_order, :sort_order)
      @sub_departments = SubDepartment.active_records.where(buyback_allowed: true).order(:name)
      @reject_reasons = BuybackRejectReason.active_records.order(:sort_order)
      @proposal = ProposalBuilder.build(@buyback_session) if @buyback_session.quoted? || @buyback_session.decision?
      @decision_totals = DecisionTotalsBuilder.build(@buyback_session) if @buyback_session.decision?
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

    def respond_to_buyback_session_update(line: nil, notice: nil, alert: nil, open_line_id: nil, remove_line_id: nil,
                                        append_line: false)
      prepare_buyback_session_view!(@buyback_session)
      @stream_line = line
      @open_line_id = open_line_id
      @remove_line_id = remove_line_id
      @append_line = append_line

      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice if notice.present?
          flash.now[:alert] = alert if alert.present?
          render "buybacks/sessions/stream_update", status: (alert.present? ? :unprocessable_entity : :ok)
        end
        format.html do
          redirect_params = {}
          redirect_params[:open_line] = @open_line_id if @open_line_id.present?
          redirect_to buybacks_session_path(@buyback_session, **redirect_params, anchor: line ? "line-#{line.id}" : nil),
                      notice: notice,
                      alert: alert
        end
      end
    end
  end
end
