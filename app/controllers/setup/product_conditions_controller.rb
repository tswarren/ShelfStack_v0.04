# frozen_string_literal: true

module Setup
  class ProductConditionsController < BaseController
    before_action :set_product_condition, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.product_conditions.view") }, only: %i[index show]
    before_action -> { authorize!("setup.product_conditions.create") }, only: %i[new create]
    before_action -> { authorize!("setup.product_conditions.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.product_conditions.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.product_conditions.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.product_conditions.delete") }, only: :destroy

    def index
      @product_conditions = ProductCondition.order(:sort_order, :name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@product_condition).limit(50)
    end

    def new
      @product_condition = ProductCondition.new(active: true, default_list_price_factor_bps: 10_000)
    end

    def create
      @product_condition = ProductCondition.new(product_condition_params)
      if @product_condition.save
        record_audit!("product_condition.created", @product_condition)
        redirect_to setup_product_condition_path(@product_condition), notice: "Product condition created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @product_condition.update(product_condition_params)
        record_audit!("product_condition.updated", @product_condition)
        redirect_to setup_product_condition_path(@product_condition), notice: "Product condition updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @product_condition.product_variants.exists?
        redirect_to setup_product_condition_path(@product_condition), alert: "Product condition cannot be deleted. Inactivate instead."
      else
        @product_condition.destroy
        record_audit!("product_condition.deleted", @product_condition)
        redirect_to setup_product_conditions_path, notice: "Product condition deleted."
      end
    end

    def inactivate
      @product_condition.inactivate!
      record_audit!("product_condition.inactivated", @product_condition)
      redirect_to setup_product_condition_path(@product_condition), notice: "Product condition inactivated."
    end

    def reactivate
      @product_condition.reactivate!
      record_audit!("product_condition.reactivated", @product_condition)
      redirect_to setup_product_condition_path(@product_condition), notice: "Product condition reactivated."
    end

    private

    def set_product_condition
      @product_condition = ProductCondition.find(params[:id])
    end

    def product_condition_params
      params.require(:product_condition).permit(
        :condition_key, :name, :short_name, :sku_component, :sort_order, :new_condition,
        :default_list_price_factor_bps, :description, :active
      )
    end
  end
end
