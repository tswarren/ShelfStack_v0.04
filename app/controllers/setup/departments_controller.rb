# frozen_string_literal: true

module Setup
  class DepartmentsController < BaseController
    before_action :set_department, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.departments.view") }, only: %i[index show]
    before_action -> { authorize!("setup.departments.create") }, only: %i[new create]
    before_action -> { authorize!("setup.departments.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.departments.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.departments.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.departments.delete") }, only: :destroy

    def index
      @departments = Department.order(:department_number)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@department).limit(50)
      @sub_departments = @department.sub_departments.order(:name)
    end

    def new
      @department = Department.new(active: true)
    end

    def create
      @department = Department.new(department_params)
      if @department.save
        record_audit!("department.created", @department)
        redirect_to setup_department_path(@department), notice: "Department created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @department.update(department_params)
        record_audit!("department.updated", @department)
        redirect_to setup_department_path(@department), notice: "Department updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @department.sub_departments.exists?
        redirect_to setup_department_path(@department), alert: "Department cannot be deleted. Inactivate instead."
      else
        @department.destroy
        record_audit!("department.deleted", @department)
        redirect_to setup_departments_path, notice: "Department deleted."
      end
    end

    def inactivate
      @department.inactivate!
      record_audit!("department.inactivated", @department)
      redirect_to setup_department_path(@department), notice: "Department inactivated."
    end

    def reactivate
      @department.reactivate!
      record_audit!("department.reactivated", @department)
      redirect_to setup_department_path(@department), notice: "Department reactivated."
    end

    private

    def set_department
      @department = Department.find(params[:id])
    end

    def department_params
      params.require(:department).permit(
        :department_number, :name, :short_name, :gl_account_code, :description, :discountable, :active
      )
    end
  end
end
