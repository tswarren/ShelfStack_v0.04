# frozen_string_literal: true

module Sourcing
  class VendorResponsesController < BaseController
    before_action -> { authorize_sourcing!("sourcing.responses.record") }, only: :create
    before_action :set_sourcing_attempt

    def create
      po_line = if params[:purchase_order_line_id].present?
        PurchaseOrderLine.joins(:purchase_order)
                         .where(purchase_orders: { store_id: sourcing_store.id })
                         .find(params[:purchase_order_line_id])
      end

      Sourcing::RecordVendorResponse.call!(
        sourcing_attempt: @sourcing_attempt,
        actor: current_user,
        quantity_confirmed: params[:quantity_confirmed].presence&.to_i || 0,
        quantity_backordered: params[:quantity_backordered].presence&.to_i || 0,
        quantity_unavailable: params[:quantity_unavailable].presence&.to_i || 0,
        quantity_canceled: params[:quantity_canceled].presence&.to_i || 0,
        quantity_failed: params[:quantity_failed].presence&.to_i || 0,
        quantity_substitute_offered: params[:quantity_substitute_offered].presence&.to_i || 0,
        final_response: ActiveModel::Type::Boolean.new.cast(params[:final_response]),
        accept_backorder: ActiveModel::Type::Boolean.new.cast(params[:accept_backorder]),
        purchase_order_line: po_line,
        vendor_reference: params[:vendor_reference],
        message: params[:message],
        notes: params[:notes]
      )

      redirect_to sourcing_run_path(@sourcing_attempt.sourcing_run), notice: "Vendor response recorded."
    rescue Sourcing::RecordVendorResponse::RecordResponseError,
           DemandAllocations::AllocateInboundPurchaseOrder::AllocateError,
           DemandAllocations::AllocateVendorBackorder::AllocateError,
           ActiveRecord::RecordNotFound => e
      redirect_to sourcing_run_path(@sourcing_attempt.sourcing_run), alert: e.message
    end

    private

    def set_sourcing_attempt
      @sourcing_attempt = SourcingAttempt.joins(:sourcing_run)
                                         .where(sourcing_runs: { store_id: sourcing_store.id })
                                         .find(params[:attempt_id])
    end
  end
end
