# frozen_string_literal: true

module Setup
  class DiscountReasonsController < BaseController
    before_action :set_discount_reason, only: %i[show edit update inactivate reactivate]
    before_action -> { authorize!("setup.discount_reasons.view") }, only: %i[index show]
    before_action -> { authorize!("setup.discount_reasons.create") }, only: %i[new create]
    before_action -> { authorize!("setup.discount_reasons.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.discount_reasons.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.discount_reasons.inactivate") }, only: :reactivate

    def index
      @discount_reasons = DiscountReason.order(:sort_order, :name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@discount_reason).limit(50)
    end

    def new
      @discount_reason = DiscountReason.new(active: true)
    end

    def create
      @discount_reason = DiscountReason.new(discount_reason_params)
      if @discount_reason.save
        record_audit!("discount_reason.created", @discount_reason)
        redirect_to setup_discount_reason_path(@discount_reason), notice: "Discount reason created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @discount_reason.update(discount_reason_params)
        record_audit!("discount_reason.updated", @discount_reason)
        redirect_to setup_discount_reason_path(@discount_reason), notice: "Discount reason updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def inactivate
      @discount_reason.inactivate!
      record_audit!("discount_reason.inactivated", @discount_reason)
      redirect_to setup_discount_reason_path(@discount_reason), notice: "Discount reason inactivated."
    end

    def reactivate
      @discount_reason.reactivate!
      record_audit!("discount_reason.reactivated", @discount_reason)
      redirect_to setup_discount_reason_path(@discount_reason), notice: "Discount reason reactivated."
    end

    private

    def set_discount_reason
      @discount_reason = DiscountReason.find(params[:id])
    end

    def discount_reason_params
      params.require(:discount_reason).permit(
        :reason_key, :name, :description, :requires_note, :requires_authorization, :active, :sort_order
      )
    end
  end
end
