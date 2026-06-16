# frozen_string_literal: true

module Setup
  class CategorySchemesController < BaseController
    before_action :set_category_scheme, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.category_schemes.view") }, only: %i[index show]
    before_action -> { authorize!("setup.category_schemes.create") }, only: %i[new create]
    before_action -> { authorize!("setup.category_schemes.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.category_schemes.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.category_schemes.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.category_schemes.delete") }, only: :destroy

    def index
      @category_schemes = CategoryScheme.order(:name)
    end

    def show
      @category_nodes = @category_scheme.category_nodes.includes(:parent).order(:sort_order, :name)
      @audit_events = AuditEvent.for_auditable(@category_scheme).limit(50)
    end

    def new
      @category_scheme = CategoryScheme.new(active: true, purpose: "store_categories")
    end

    def create
      @category_scheme = CategoryScheme.new(category_scheme_params)
      if @category_scheme.save
        record_audit!("category_scheme.created", @category_scheme)
        redirect_to setup_category_scheme_path(@category_scheme), notice: "Category scheme created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @category_scheme.update(category_scheme_params)
        record_audit!("category_scheme.updated", @category_scheme)
        redirect_to setup_category_scheme_path(@category_scheme), notice: "Category scheme updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @category_scheme.category_nodes.exists?
        redirect_to setup_category_scheme_path(@category_scheme), alert: "Category scheme cannot be deleted. Inactivate instead."
      else
        @category_scheme.destroy
        record_audit!("category_scheme.deleted", @category_scheme)
        redirect_to setup_category_schemes_path, notice: "Category scheme deleted."
      end
    end

    def inactivate
      @category_scheme.inactivate!
      record_audit!("category_scheme.inactivated", @category_scheme)
      redirect_to setup_category_scheme_path(@category_scheme), notice: "Category scheme inactivated."
    end

    def reactivate
      @category_scheme.reactivate!
      record_audit!("category_scheme.reactivated", @category_scheme)
      redirect_to setup_category_scheme_path(@category_scheme), notice: "Category scheme reactivated."
    end

    private

    def set_category_scheme
      @category_scheme = CategoryScheme.find(params[:id])
    end

    def category_scheme_params
      params.require(:category_scheme).permit(:scheme_key, :name, :purpose, :active)
    end
  end
end
