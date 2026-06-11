# frozen_string_literal: true

module Items
  class ProductVariantsController < BaseController
    before_action :set_product_variant, only: %i[show edit update destroy inactivate reactivate regenerate_name]
    before_action -> { authorize!("items.product_variants.view") }, only: %i[index show]
    before_action -> { authorize!("items.product_variants.create") }, only: %i[new create]
    before_action -> { authorize!("items.product_variants.update") }, only: %i[edit update regenerate_name]
    before_action -> { authorize!("items.product_variants.inactivate") }, only: :inactivate
    before_action -> { authorize!("items.product_variants.reactivate") }, only: :reactivate
    before_action -> { authorize!("items.product_variants.delete") }, only: :destroy

    def index
      @product_variants = ProductVariant.includes(:product, :category, :condition).order("products.name", :sku)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@product_variant).limit(50)
    end

    def new
      @product_variant = ProductVariant.new(active: true, inventory_behavior: "standard_physical")
      @product_variant.product = Product.find(params[:product_id]) if params[:product_id].present?
      @product_variant.condition = ProductCondition.find(params[:condition_id]) if params[:condition_id].present?
      load_form_collections
    end

    def create
      @product_variant = ProductVariant.new(product_variant_params)
      load_form_collections
      if @product_variant.save
        record_audit!("product_variant.created", @product_variant, details: { "sku" => @product_variant.sku })
        redirect_to items_product_variant_path(@product_variant), notice: "Product variant created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      load_form_collections
      if @product_variant.update(product_variant_params)
        record_audit!("product_variant.updated", @product_variant)
        redirect_to items_product_variant_path(@product_variant), notice: "Product variant updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @product_variant.destroy
      record_audit!("product_variant.deleted", @product_variant)
      redirect_to items_product_variants_path, notice: "Product variant deleted."
    end

    def inactivate
      @product_variant.inactivate!
      record_audit!("product_variant.inactivated", @product_variant)
      redirect_to items_product_variant_path(@product_variant), notice: "Product variant inactivated."
    end

    def reactivate
      @product_variant.reactivate!
      record_audit!("product_variant.reactivated", @product_variant)
      redirect_to items_product_variant_path(@product_variant), notice: "Product variant reactivated."
    end

    def regenerate_name
      @product_variant.update!(name: ProductNameRenderer.variant_name(@product_variant))
      record_audit!("product_variant.name_regenerated", @product_variant)
      redirect_to items_product_variant_path(@product_variant), notice: "Variant name regenerated."
    end

    private

    def set_product_variant
      @product_variant = ProductVariant.find(params[:id])
    end

    def load_form_collections
      @products = Product.active_records.order(:name)
      @categories = Category.active_records.includes(:department).order("departments.department_number", :name)
      @conditions = ProductCondition.active_records.order(:sort_order, :name)
      @display_locations = DisplayLocation.active_records.order(:sort_order, :name)
    end

    def product_variant_params
      params.require(:product_variant).permit(
        :product_id, :name, :name_override, :short_name, :sku, :condition_id, :category_id,
        :display_location_id, :attribute1_value, :attribute1_sku_component, :attribute2_value,
        :attribute2_sku_component, :selling_price_cents, :pricing_model_override,
        :inventory_behavior, :active
      )
    end
  end
end
