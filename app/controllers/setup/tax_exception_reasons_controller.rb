# frozen_string_literal: true

module Setup
  class TaxExceptionReasonsController < BaseController
    before_action :set_tax_exception_reason, only: %i[show edit update inactivate reactivate]
    before_action -> { authorize!("setup.tax_exception_reasons.view") }, only: %i[index show]
    before_action -> { authorize!("setup.tax_exception_reasons.create") }, only: %i[new create]
    before_action -> { authorize!("setup.tax_exception_reasons.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.tax_exception_reasons.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.tax_exception_reasons.inactivate") }, only: :reactivate

    def index
      @tax_exception_reasons = TaxExceptionReason.order(:sort_order, :name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@tax_exception_reason).limit(50)
    end

    def new
      @tax_exception_reason = TaxExceptionReason.new(active: true, exception_type: "exemption")
    end

    def create
      @tax_exception_reason = TaxExceptionReason.new(tax_exception_reason_params)
      if @tax_exception_reason.save
        record_audit!("tax_exception_reason.created", @tax_exception_reason)
        redirect_to setup_tax_exception_reason_path(@tax_exception_reason), notice: "Tax exception reason created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @tax_exception_reason.update(tax_exception_reason_params)
        record_audit!("tax_exception_reason.updated", @tax_exception_reason)
        redirect_to setup_tax_exception_reason_path(@tax_exception_reason), notice: "Tax exception reason updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def inactivate
      @tax_exception_reason.inactivate!
      record_audit!("tax_exception_reason.inactivated", @tax_exception_reason)
      redirect_to setup_tax_exception_reason_path(@tax_exception_reason), notice: "Tax exception reason inactivated."
    end

    def reactivate
      @tax_exception_reason.reactivate!
      record_audit!("tax_exception_reason.reactivated", @tax_exception_reason)
      redirect_to setup_tax_exception_reason_path(@tax_exception_reason), notice: "Tax exception reason reactivated."
    end

    private

    def set_tax_exception_reason
      @tax_exception_reason = TaxExceptionReason.find(params[:id])
    end

    def tax_exception_reason_params
      params.require(:tax_exception_reason).permit(
        :reason_key, :name, :exception_type, :requires_note, :requires_certificate, :active, :sort_order
      )
    end
  end
end
