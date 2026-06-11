# frozen_string_literal: true

module Setup
  class AccountingMappingsController < BaseController
    before_action :set_accounting_mapping, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.accounting_mappings.view") }, only: %i[index show]
    before_action -> { authorize!("setup.accounting_mappings.create") }, only: %i[new create]
    before_action -> { authorize!("setup.accounting_mappings.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.accounting_mappings.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.accounting_mappings.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.accounting_mappings.delete") }, only: :destroy
    before_action :load_form_collections, only: %i[new create edit update]

    def index
      @accounting_mappings = AccountingMapping.includes(:merchandise_class, :condition, :category_node).order(:sort_order, :id)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@accounting_mapping).limit(50)
    end

    def new
      @accounting_mapping = AccountingMapping.new(active: true, sort_order: 0)
    end

    def create
      @accounting_mapping = AccountingMapping.new(accounting_mapping_params)
      if @accounting_mapping.save
        record_audit!("accounting_mapping.created", @accounting_mapping)
        redirect_to setup_accounting_mapping_path(@accounting_mapping), notice: "Accounting mapping created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @accounting_mapping.update(accounting_mapping_params)
        record_audit!("accounting_mapping.updated", @accounting_mapping)
        redirect_to setup_accounting_mapping_path(@accounting_mapping), notice: "Accounting mapping updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @accounting_mapping.destroy
      record_audit!("accounting_mapping.deleted", @accounting_mapping)
      redirect_to setup_accounting_mappings_path, notice: "Accounting mapping deleted."
    end

    def inactivate
      @accounting_mapping.inactivate!
      record_audit!("accounting_mapping.inactivated", @accounting_mapping)
      redirect_to setup_accounting_mapping_path(@accounting_mapping), notice: "Accounting mapping inactivated."
    end

    def reactivate
      @accounting_mapping.reactivate!
      record_audit!("accounting_mapping.reactivated", @accounting_mapping)
      redirect_to setup_accounting_mapping_path(@accounting_mapping), notice: "Accounting mapping reactivated."
    end

    private

    def set_accounting_mapping
      @accounting_mapping = AccountingMapping.find(params[:id])
    end

    def load_form_collections
      @merchandise_classes = MerchandiseClass.active_records.order(:name)
      @conditions = ProductCondition.active_records.order(:sort_order, :name)
      @category_nodes = CategoryNode.active_records.includes(:category_scheme).order("category_schemes.name", :name)
    end

    def accounting_mapping_params
      params.require(:accounting_mapping).permit(
        :merchandise_class_id, :condition_id, :category_node_id, :product_type,
        :sales_account_code, :reporting_bucket, :gl_export_code, :description, :sort_order, :active
      )
    end
  end
end
