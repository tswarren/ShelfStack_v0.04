# frozen_string_literal: true

module Sourcing
  class AttemptsController < BaseController
    before_action -> { authorize_sourcing!("sourcing.attempts.create") }, only: :create
    before_action -> { authorize_sourcing!("sourcing.attempts.submit") }, only: :submit
    before_action -> { authorize_sourcing!("sourcing.attempts.cancel") }, only: :cancel
    before_action -> { authorize_sourcing!("sourcing.attempts.cascade") }, only: :cascade
    before_action :set_sourcing_run, only: :create
    before_action :set_sourcing_attempt, only: %i[submit cancel cascade]

    def create
      vendor = Vendor.find(params[:vendor_id])
      manual_override = ActiveModel::Type::Boolean.new.cast(params[:manual_vendor_override]) == true
      if manual_override && !Authorization.allowed?(user: current_user, permission_key: "sourcing.vendor_override", store: sourcing_store)
        return redirect_to sourcing_run_path(@sourcing_run), alert: "Vendor override authorization required."
      end

      attempt = Sourcing::CreateAttempt.call!(
        sourcing_run: @sourcing_run,
        actor: current_user,
        vendor: vendor,
        quantity: params[:quantity].presence&.to_i || 1,
        manual_vendor_override: manual_override,
        override_reason: params[:override_reason],
        override_authorized_by_user: manual_override ? current_user : nil,
        purchase_order_line: resolve_po_line,
        notes: params[:notes]
      )

      redirect_to sourcing_run_path(@sourcing_run), notice: "Sourcing attempt created."
    rescue Sourcing::CreateAttempt::CreateAttemptError, ActiveRecord::RecordNotFound => e
      redirect_to sourcing_run_path(@sourcing_run), alert: e.message
    end

    def submit
      Sourcing::SubmitAttempt.call!(sourcing_attempt: @sourcing_attempt, actor: current_user)
      redirect_to sourcing_run_path(@sourcing_attempt.sourcing_run), notice: "Attempt submitted to vendor."
    rescue Sourcing::SubmitAttempt::SubmitAttemptError => e
      redirect_to sourcing_run_path(@sourcing_attempt.sourcing_run), alert: e.message
    end

    def cancel
      Sourcing::CancelAttempt.call!(
        sourcing_attempt: @sourcing_attempt,
        actor: current_user,
        cancel_reason: params[:cancel_reason].presence || "Staff canceled"
      )
      redirect_to sourcing_run_path(@sourcing_attempt.sourcing_run), notice: "Attempt canceled."
    rescue Sourcing::CancelAttempt::CancelAttemptError => e
      redirect_to sourcing_run_path(@sourcing_attempt.sourcing_run), alert: e.message
    end

    def cascade
      vendor = Vendor.find(params[:vendor_id])
      manual_override = ActiveModel::Type::Boolean.new.cast(params[:manual_vendor_override]) == true
      if manual_override && !Authorization.allowed?(user: current_user, permission_key: "sourcing.vendor_override", store: sourcing_store)
        return redirect_to sourcing_run_path(@sourcing_attempt.sourcing_run), alert: "Vendor override authorization required."
      end

      attempt = Sourcing::Cascade.call!(
        previous_attempt: @sourcing_attempt,
        actor: current_user,
        vendor: vendor,
        quantity: params[:quantity].presence&.to_i || 1,
        cascade_reason: params[:cascade_reason],
        manual_vendor_override: manual_override,
        override_reason: params[:override_reason],
        override_authorized_by_user: manual_override ? current_user : nil,
        notes: params[:notes]
      )

      redirect_to sourcing_run_path(@sourcing_attempt.sourcing_run),
                  notice: "Cascade attempt ##{attempt.sequence_number} created (pending)."
    rescue Sourcing::Cascade::CascadeError, ActiveRecord::RecordNotFound => e
      redirect_to sourcing_run_path(@sourcing_attempt.sourcing_run), alert: e.message
    end

    private

    def resolve_po_line
      return nil if params[:purchase_order_line_id].blank?

      PurchaseOrderLine.joins(:purchase_order)
                       .where(purchase_orders: { store_id: sourcing_store.id })
                       .find(params[:purchase_order_line_id])
    end
  end
end
