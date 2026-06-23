# frozen_string_literal: true

module Setup
  class StoredValueReasonCodesController < BaseController
    before_action :set_reason_code, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.stored_value_reason_codes.view") }, only: %i[index show]
    before_action -> { authorize!("setup.stored_value_reason_codes.create") }, only: %i[new create]
    before_action -> { authorize!("setup.stored_value_reason_codes.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.stored_value_reason_codes.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.stored_value_reason_codes.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.stored_value_reason_codes.delete") }, only: :destroy

    def index
      @reason_codes = StoredValueReasonCode.order(:name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@reason_code).limit(50)
    end

    def new
      @reason_code = StoredValueReasonCode.new(active: true)
    end

    def create
      @reason_code = StoredValueReasonCode.new(reason_code_params)
      if @reason_code.save
        record_audit!("stored_value_reason_code.created", @reason_code)
        redirect_to setup_stored_value_reason_code_path(@reason_code), notice: "Reason code created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @reason_code.update(reason_code_params)
        record_audit!("stored_value_reason_code.updated", @reason_code)
        redirect_to setup_stored_value_reason_code_path(@reason_code), notice: "Reason code updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @reason_code.stored_value_ledger_entries.exists? || @reason_code.stored_value_transfers.exists?
        redirect_to setup_stored_value_reason_code_path(@reason_code), alert: "Reason code cannot be deleted. Inactivate instead."
      else
        @reason_code.destroy!
        record_audit!("stored_value_reason_code.deleted", @reason_code)
        redirect_to setup_stored_value_reason_codes_path, notice: "Reason code deleted."
      end
    end

    def inactivate
      @reason_code.inactivate!
      record_audit!("stored_value_reason_code.inactivated", @reason_code)
      redirect_to setup_stored_value_reason_code_path(@reason_code), notice: "Reason code inactivated."
    end

    def reactivate
      @reason_code.reactivate!
      record_audit!("stored_value_reason_code.reactivated", @reason_code)
      redirect_to setup_stored_value_reason_code_path(@reason_code), notice: "Reason code reactivated."
    end

    private

    def set_reason_code
      @reason_code = StoredValueReasonCode.find(params[:id])
    end

    def reason_code_params
      params.require(:stored_value_reason_code).permit(:reason_key, :name, :description, :active)
    end
  end
end
