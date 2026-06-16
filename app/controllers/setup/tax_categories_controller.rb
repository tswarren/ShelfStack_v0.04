# frozen_string_literal: true

module Setup
  class TaxCategoriesController < BaseController
    before_action :set_tax_category, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.tax_categories.view") }, only: %i[index show]
    before_action -> { authorize!("setup.tax_categories.create") }, only: %i[new create]
    before_action -> { authorize!("setup.tax_categories.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.tax_categories.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.tax_categories.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.tax_categories.delete") }, only: :destroy

    def index
      @tax_categories = TaxCategory.order(:sort_order, :name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@tax_category).limit(50)
    end

    def new
      @tax_category = TaxCategory.new(active: true, sort_order: 0)
    end

    def create
      @tax_category = TaxCategory.new(tax_category_params)
      if @tax_category.save
        record_audit!("tax_category.created", @tax_category)
        redirect_to setup_tax_category_path(@tax_category), notice: "Tax category created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @tax_category.update(tax_category_params)
        record_audit!("tax_category.updated", @tax_category)
        redirect_to setup_tax_category_path(@tax_category), notice: "Tax category updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @tax_category.sub_departments.exists? || @tax_category.store_tax_category_rates.exists?
        redirect_to setup_tax_category_path(@tax_category), alert: "Tax category cannot be deleted. Inactivate instead."
      else
        @tax_category.destroy
        record_audit!("tax_category.deleted", @tax_category)
        redirect_to setup_tax_categories_path, notice: "Tax category deleted."
      end
    end

    def inactivate
      @tax_category.inactivate!
      record_audit!("tax_category.inactivated", @tax_category)
      redirect_to setup_tax_category_path(@tax_category), notice: "Tax category inactivated."
    end

    def reactivate
      @tax_category.reactivate!
      record_audit!("tax_category.reactivated", @tax_category)
      redirect_to setup_tax_category_path(@tax_category), notice: "Tax category reactivated."
    end

    private

    def set_tax_category
      @tax_category = TaxCategory.find(params[:id])
    end

    def tax_category_params
      params.require(:tax_category).permit(:name, :short_name, :sort_order, :active)
    end
  end
end
