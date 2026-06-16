# frozen_string_literal: true

module Setup
  class SubDepartmentsController < BaseController
    before_action :set_sub_department, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.sub_departments.view") }, only: %i[index show]
    before_action -> { authorize!("setup.sub_departments.create") }, only: %i[new create]
    before_action -> { authorize!("setup.sub_departments.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.sub_departments.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.sub_departments.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.sub_departments.delete") }, only: :destroy
    before_action :load_form_collections, only: %i[new create edit update]

    def index
      @sub_department_rows = SubDepartmentIndexTree.rows
    end

    def show
      @audit_events = AuditEvent.for_auditable(@sub_department).limit(50)
    end

    def new
      @sub_department = SubDepartment.new(active: true)
    end

    def create
      @sub_department = SubDepartment.new(sub_department_params)
      if @sub_department.save
        record_audit!("sub_department.created", @sub_department)
        redirect_to setup_sub_department_path(@sub_department), notice: "Subdepartment created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      if @sub_department.update(sub_department_params)
        record_audit!("sub_department.updated", @sub_department)
        redirect_to setup_sub_department_path(@sub_department), notice: "Subdepartment updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @sub_department.product_variants.exists?
        redirect_to setup_sub_department_path(@sub_department),
                    alert: "Subdepartment cannot be deleted. Inactivate instead."
      else
        @sub_department.destroy
        record_audit!("sub_department.deleted", @sub_department)
        redirect_to setup_sub_departments_path, notice: "Subdepartment deleted."
      end
    end

    def inactivate
      @sub_department.inactivate!
      record_audit!("sub_department.inactivated", @sub_department)
      redirect_to setup_sub_department_path(@sub_department), notice: "Subdepartment inactivated."
    end

    def reactivate
      @sub_department.reactivate!
      record_audit!("sub_department.reactivated", @sub_department)
      redirect_to setup_sub_department_path(@sub_department), notice: "Subdepartment reactivated."
    end

    private

    def set_sub_department
      @sub_department = SubDepartment.find(params[:id])
    end

    def load_form_collections
      @tax_categories = TaxCategory.active_records.order(:sort_order, :name)
      @departments = Department.active_records.order(:department_number, :name)
    end

    def sub_department_params
      params.require(:sub_department).permit(
        :sub_department_key, :name, :short_name, :department_id, :default_pricing_model, :default_tax_category_id,
        :vendor_returnable_default, :buyback_allowed, :active
      )
    end
  end
end
