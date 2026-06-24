# frozen_string_literal: true

module Buybacks
  class LinesController < BaseController
    before_action :set_session
    before_action :set_line, only: %i[
      update reject price_override offer_override resolve select_variant intake
      update_proposal record_decision destroy
    ]

    def create
      return unless authorize_buyback!("buybacks.update")

      line = AddLine.call!(
        session: @buyback_session,
        actor: current_user,
        identifier_entered: params[:identifier],
        title_snapshot: params[:title],
        notes: params[:notes]
      )
      redirect_to buybacks_session_path(@buyback_session, anchor: "line-#{line.id}")
    rescue ArgumentError => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def update
      return unless authorize_buyback!("buybacks.update")

      UpdateLine.call!(
        line: @line,
        actor: current_user,
        product_condition: condition_from_params,
        sub_department: sub_department_from_params,
        signed_copy: params.dig(:buyback_line, :signed_copy),
        notes: params.dig(:buyback_line, :notes)
      )
      redirect_to buybacks_session_path(@buyback_session)
    rescue ArgumentError => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def update_proposal
      return unless authorize_buyback!("buybacks.update")

      UpdateProposalLine.call!(
        line: @line,
        session: @buyback_session,
        actor: current_user,
        product_condition: condition_from_params,
        sub_department: sub_department_from_params,
        base_price_cents: params[:base_price_cents],
        base_price_source: params[:base_price_source],
        proposed_resale_price_cents: params[:proposed_resale_price_cents],
        proposed_cash_offer_cents: params[:proposed_cash_offer_cents],
        proposed_trade_credit_offer_cents: params[:proposed_trade_credit_offer_cents],
        resale_override_reason: params[:resale_override_reason],
        cash_override_reason: params[:cash_override_reason],
        trade_credit_override_reason: params[:trade_credit_override_reason],
        signed_copy: params[:signed_copy],
        notes: params[:notes]
      )
      redirect_to buybacks_session_path(@buyback_session, anchor: "line-#{@line.id}"), notice: "Line proposal updated."
    rescue Buybacks::UpdateProposalLine::Error, Buybacks::Eligibility::Error => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def record_decision
      return unless authorize_buyback!("buybacks.decisions.update")

      RecordCustomerDecision.call!(
        line: @line,
        session: @buyback_session,
        actor: current_user,
        outcome: params[:outcome]
      )
      redirect_to buybacks_session_path(@buyback_session), notice: "Customer decision recorded."
    rescue Buybacks::RecordCustomerDecision::Error => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def destroy
      return unless authorize_buyback!("buybacks.update")

      RemoveLine.call!(line: @line, session: @buyback_session, actor: current_user)
      redirect_to buybacks_session_path(@buyback_session), notice: "Line removed."
    rescue Buybacks::RemoveLine::Error => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def resolve
      return unless authorize_buyback!("buybacks.update")

      result = ResolveItem.call(
        store: buybacks_store,
        identifier: params[:identifier] || @line.identifier_entered,
        title: params[:title] || @line.title_snapshot
      )

      respond_to do |format|
        format.html do
          render partial: "buybacks/sessions/resolve_results",
                 locals: {
                   result: result,
                   line: @line,
                   session: @buyback_session,
                   conditions: buyback_conditions,
                   sub_departments: buyback_sub_departments
                 },
                 layout: false
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@line, :resolve),
            partial: "buybacks/sessions/resolve_results",
            locals: {
              result: result,
              line: @line,
              session: @buyback_session,
              conditions: buyback_conditions,
              sub_departments: buyback_sub_departments
            }
          )
        end
      end
    end

    def select_variant
      return unless authorize_buyback!("buybacks.update")

      variant = ProductVariant.find(params[:product_variant_id])
      catalog_item = variant.product.catalog_item

      @line.update!(
        product_variant: variant,
        product: variant.product,
        catalog_item: catalog_item,
        product_condition: variant.condition,
        sub_department: variant.sub_department,
        title_snapshot: catalog_item&.title || variant.product.name,
        variant_sku_snapshot: variant.sku,
        condition_snapshot: variant.condition&.name,
        status: "resolved"
      )
      redirect_to buybacks_session_path(@buyback_session), notice: "Item linked to line."
    rescue ActiveRecord::RecordNotFound, ArgumentError => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def intake
      return unless authorize_buyback!("buybacks.create_intake_item")

      sub_department = SubDepartment.find(params[:sub_department_id])
      condition = ProductCondition.find(params[:product_condition_id]) if params[:product_condition_id].present?
      result = CreateIntakeItem.call!(
        session: @buyback_session,
        actor: current_user,
        line: @line,
        title: params[:title] || @line.title_snapshot,
        sub_department: sub_department,
        condition: condition,
        identifier: params[:identifier] || @line.identifier_entered,
        list_price_cents: params[:list_price_cents]
      )
      notice = result.created_new_catalog ? "Intake item created." : "Catalog item linked."
      redirect_to buybacks_session_path(@buyback_session), notice: notice
    rescue Buybacks::CreateIntakeItem::Error, Buybacks::FindOrCreateGradedUsedVariant::Error => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def reject
      return unless authorize_buyback!("buybacks.reject")

      reason = BuybackRejectReason.find(params[:buyback_reject_reason_id]) if params[:buyback_reject_reason_id].present?
      outcome = params[:outcome].presence || "rejected_by_store"
      RejectLine.call!(
        line: @line,
        actor: current_user,
        outcome: outcome,
        reject_reason: reason
      )
      redirect_to buybacks_session_path(@buyback_session), notice: "Line rejected."
    rescue Buybacks::RejectLine::Error => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def price_override
      return unless authorize_buyback!("buybacks.price_override")

      ApplyPriceOverride.call!(
        line: @line,
        actor: current_user,
        resale_price_cents: params[:resale_price_cents].to_i,
        override_reason: params[:override_reason]
      )
      redirect_to buybacks_session_path(@buyback_session), notice: "Resale price updated."
    rescue Buybacks::ApplyPriceOverride::Error => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    def offer_override
      return unless authorize_buyback!("buybacks.price_override")

      ApplyOfferOverride.call!(
        line: @line,
        actor: current_user,
        offer_cents: params[:offer_cents].to_i,
        override_reason: params[:override_reason],
        offer_type: params[:offer_type].presence || "cash"
      )
      redirect_to buybacks_session_path(@buyback_session), notice: "Offer updated."
    rescue Buybacks::ApplyOfferOverride::Error => e
      redirect_to buybacks_session_path(@buyback_session), alert: e.message
    end

    private

    def set_session
      @buyback_session = BuybackSession.for_store(buybacks_store).find(params[:session_id])
    end

    def set_line
      @line = @buyback_session.buyback_lines.find(params[:id])
    end

    def condition_from_params
      id = params.dig(:buyback_line, :product_condition_id) || params[:product_condition_id]
      ProductCondition.find(id) if id.present?
    end

    def sub_department_from_params
      id = params.dig(:buyback_line, :sub_department_id) || params[:sub_department_id]
      SubDepartment.find(id) if id.present?
    end

    def buyback_conditions
      ProductCondition.buyback_eligible.order(:buyback_sort_order, :sort_order)
    end

    def buyback_sub_departments
      SubDepartment.active_records.where(buyback_allowed: true).order(:name)
    end
  end
end
