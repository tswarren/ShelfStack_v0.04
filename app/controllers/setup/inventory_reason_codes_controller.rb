# frozen_string_literal: true

module Setup
  class InventoryReasonCodesController < BaseController
    before_action :set_reason_code, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.inventory_reason_codes.view") }, only: %i[index show]
    before_action -> { authorize!("setup.inventory_reason_codes.create") }, only: %i[new create]
    before_action -> { authorize!("setup.inventory_reason_codes.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.inventory_reason_codes.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.inventory_reason_codes.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.inventory_reason_codes.delete") }, only: :destroy

    def index
      @reason_codes = InventoryReasonCode.order(:sort_order, :name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@reason_code).limit(50)
    end

    def new
      @reason_code = InventoryReasonCode.new(active: true, sort_order: 0)
    end

    def create
      @reason_code = InventoryReasonCode.new(reason_code_params)
      if @reason_code.save
        record_audit!("inventory_reason_code.created", @reason_code)
        redirect_to setup_inventory_reason_code_path(@reason_code), notice: "Reason code created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @reason_code.update(reason_code_params)
        record_audit!("inventory_reason_code.updated", @reason_code)
        redirect_to setup_inventory_reason_code_path(@reason_code), notice: "Reason code updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @reason_code.inventory_adjustment_lines.exists? || @reason_code.inventory_ledger_entries.exists?
        redirect_to setup_inventory_reason_code_path(@reason_code), alert: "Reason code cannot be deleted. Inactivate instead."
      else
        @reason_code.destroy!
        record_audit!("inventory_reason_code.deleted", @reason_code)
        redirect_to setup_inventory_reason_codes_path, notice: "Reason code deleted."
      end
    end

    def inactivate
      @reason_code.inactivate!
      record_audit!("inventory_reason_code.inactivated", @reason_code)
      redirect_to setup_inventory_reason_code_path(@reason_code), notice: "Reason code inactivated."
    end

    def reactivate
      @reason_code.reactivate!
      record_audit!("inventory_reason_code.reactivated", @reason_code)
      redirect_to setup_inventory_reason_code_path(@reason_code), notice: "Reason code reactivated."
    end

    private

    def set_reason_code
      @reason_code = InventoryReasonCode.find(params[:id])
    end

    def reason_code_params
      params.require(:inventory_reason_code).permit(:reason_key, :name, :sort_order, :active)
    end
  end
end
