# frozen_string_literal: true

module Setup
  class CategoriesController < BaseController
    before_action :set_category, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.categories.view") }, only: %i[index show]
    before_action -> { authorize!("setup.categories.create") }, only: %i[new create]
    before_action -> { authorize!("setup.categories.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.categories.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.categories.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.categories.delete") }, only: :destroy

    def index
      @categories = Category.includes(:department, :default_tax_category).order("departments.department_number", :sort_order, :name)
      @categories = @categories.where(department_id: params[:department_id]) if params[:department_id].present?
    end

    def show
      @audit_events = AuditEvent.for_auditable(@category).limit(50)
    end

    def new
      @category = Category.new(active: true, sort_order: 0)
      load_form_collections
    end

    def create
      @category = Category.new(category_params)
      if @category.save
        record_audit!("category.created", @category)
        redirect_to setup_category_path(@category), notice: "Category created."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      if @category.update(category_params)
        record_audit!("category.updated", @category)
        redirect_to setup_category_path(@category), notice: "Category updated."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category.destroy
      record_audit!("category.deleted", @category)
      redirect_to setup_categories_path, notice: "Category deleted."
    end

    def inactivate
      @category.inactivate!
      record_audit!("category.inactivated", @category)
      redirect_to setup_category_path(@category), notice: "Category inactivated."
    end

    def reactivate
      @category.reactivate!
      record_audit!("category.reactivated", @category)
      redirect_to setup_category_path(@category), notice: "Category reactivated."
    end

    private

    def set_category
      @category = Category.find(params[:id])
    end

    def load_form_collections
      @departments = Department.active_records.order(:department_number)
      @tax_categories = TaxCategory.active_records.order(:sort_order, :name)
      @sub_departments = SubDepartment.active_records.order(:name)
    end

    def category_params
      params.require(:category).permit(
        :department_id, :sub_department_id, :name, :short_name, :sort_order, :default_pricing_model,
        :default_margin_target_bps, :default_supplier_discount_bps, :default_tax_category_id, :active
      )
    end
  end
end
