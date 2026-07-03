# frozen_string_literal: true

module Sourcing
  class RunsController < BaseController
    before_action -> { authorize_sourcing!("sourcing.runs.create") }, only: :create
    before_action -> { authorize_sourcing!("sourcing.runs.close") }, only: :close
    before_action -> { authorize_sourcing!("sourcing.attempts.cancel") }, only: :cancel
    before_action :set_sourcing_run, only: %i[show close cancel]

    def index
      @sourcing_runs = SourcingRun.includes(:demand_line, :product_variant, :started_by_user)
                                  .where(store: sourcing_store)
                                  .order(started_at: :desc)
      apply_filters!
    end

    def show
      @demand_line = @sourcing_run.demand_line
      @attempts = @sourcing_run.sourcing_attempts.includes(:vendor, :vendor_responses).order(:sequence_number)
      @unresolved_for_sourcing = Sourcing::UnresolvedQuantity.for_demand_line(@demand_line)
      @run_unresolved = Sourcing::UnresolvedQuantity.for_sourcing_run(@sourcing_run)
      @suggested_vendors = Sourcing::SuggestVendors.call!(variant: @sourcing_run.product_variant)
      @eligible_po_lines = if @demand_line.product_variant.present?
        PurchaseOrderLine.joins(:purchase_order)
                         .includes(:purchase_order, :vendor)
                         .where(purchase_orders: { store_id: sourcing_store.id, status: %w[draft submitted partially_received] })
                         .where(product_variant_id: @demand_line.product_variant_id)
                         .where.not(status: %w[received cancelled closed_short closed])
                         .order("purchase_orders.created_at DESC")
      else
        []
      end
      @audit_events = AuditEvent.where(auditable: [ @sourcing_run ] + @attempts.to_a)
                                .or(AuditEvent.where(auditable: @attempts.flat_map(&:vendor_responses)))
                                .order(occurred_at: :desc)
                                .limit(50)
    end

    def create
      demand_line = DemandLine.where(store: sourcing_store).find(params[:demand_line_id])
      @sourcing_run = Sourcing::StartRun.call!(
        demand_line: demand_line,
        actor: current_user,
        quantity: params[:quantity].presence&.to_i,
        notes: params[:notes]
      )
      redirect_to sourcing_run_path(@sourcing_run), notice: "Sourcing run started."
    rescue Sourcing::StartRun::StartRunError, ActiveRecord::RecordNotFound => e
      redirect_back fallback_location: demand_demand_line_path(params[:demand_line_id]), alert: e.message
    end

    def close
      return unless authorize_sourcing!("sourcing.runs.close")

      Sourcing::CloseRun.call!(
        sourcing_run: @sourcing_run,
        actor: current_user,
        close_reason: params[:close_reason]
      )
      redirect_to sourcing_run_path(@sourcing_run), notice: "Sourcing run closed."
    rescue Sourcing::CloseRun::CloseRunError => e
      redirect_to sourcing_run_path(@sourcing_run), alert: e.message
    end

    def cancel
      return unless authorize_sourcing!("sourcing.attempts.cancel")

      Sourcing::CancelRun.call!(
        sourcing_run: @sourcing_run,
        actor: current_user,
        cancel_reason: params[:cancel_reason].presence || "Staff canceled"
      )
      redirect_to sourcing_run_path(@sourcing_run), notice: "Sourcing run canceled."
    rescue Sourcing::CancelRun::CancelRunError => e
      redirect_to sourcing_run_path(@sourcing_run), alert: e.message
    end

    private

    def apply_filters!
      @sourcing_runs = @sourcing_runs.where(status: params[:status]) if params[:status].present?

      if params[:capture_intent].present?
        @sourcing_runs = @sourcing_runs.joins(:demand_line)
                                       .where(demand_lines: { capture_intent: params[:capture_intent] })
      end

      if params[:queue] == "needs_review"
        @sourcing_runs = @sourcing_runs.where(status: "needs_review")
      end
    end
  end
end
