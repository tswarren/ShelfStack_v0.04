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
      @product_variants = ProductVariant.includes(:product, :sub_department, :condition).order("products.name", :sku)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@product_variant).limit(50)
      @manage_inventory_behavior = manage_inventory_behavior?
      if current_store.present? && Inventory::Eligibility.eligible?(@product_variant)
        @order_quantity = Purchasing::OrderQuantityLookup.for_variant(
          store: current_store,
          variant: @product_variant
        )
      end
      @source_hint = current_store.present? ? Inventory::SourceHint.for(variant: @product_variant, store: current_store) : nil
    end

    def new
      @product_variant = ProductVariant.new(active: true)
      @product_variant.product = Product.find(params[:product_id]) if params[:product_id].present?
      @product_variant.condition = ProductCondition.find(params[:condition_id]) if params[:condition_id].present?
      apply_variant_defaults!
      Items::InventoryTrackingSync.seed_defaults_from_product!(variant: @product_variant)
      load_form_collections
    end

    def create
      @product_variant = ProductVariant.new(product_variant_params.except(:inventory_tracking, :inventory_behavior))
      if params.dig(:product_variant, :inventory_tracking).present?
        apply_tracking_sync!
      else
        Items::InventoryTrackingSync.seed_defaults_from_product!(variant: @product_variant)
      end
      VariantClassificationSetup.apply!(variant: @product_variant)
      load_form_collections
      if @product_variant.save
        record_audit!("product_variant.created", @product_variant, details: { "sku" => @product_variant.sku })
        redirect_to variant_return_path(@product_variant), notice: "Product variant created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
      preview_tracking_change if legacy_behavior_changed_in_params?
    end

    def update
      load_form_collections
      preview_tracking_change if legacy_behavior_changed_in_params?

      attrs = product_variant_params.except(:inventory_tracking)

      if legacy_behavior_changed_in_params?
        Items::InventoryTrackingSync.apply_legacy_behavior_edit!(
          variant: @product_variant,
          inventory_behavior: product_variant_params[:inventory_behavior]
        )
        attrs = attrs.except(:inventory_behavior).merge(
          inventory_tracking_override: nil,
          inventory_behavior: @product_variant.inventory_behavior
        )
      elsif tracking_selection_changed?
        apply_tracking_sync!
        attrs = attrs.except(:inventory_behavior).merge(
          inventory_tracking_override: @product_variant.inventory_tracking_override,
          inventory_behavior: @product_variant.inventory_behavior
        )
      end

      if @product_variant.update(attrs)
        record_audit!("product_variant.updated", @product_variant)
        redirect_to variant_return_path(@product_variant), notice: "Product variant updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      product = @product_variant.product
      @product_variant.destroy
      record_audit!("product_variant.deleted", @product_variant)
      redirect_to Items::ReturnPath.for(
        record: product,
        return_to: params[:return_to].presence || "item",
        tab: "item_setup"
      ), notice: "Product variant deleted."
    end

    def inactivate
      @product_variant.inactivate!
      record_audit!("product_variant.inactivated", @product_variant)
      redirect_to variant_return_path(@product_variant), notice: "Product variant inactivated."
    end

    def reactivate
      @product_variant.reactivate!
      record_audit!("product_variant.reactivated", @product_variant)
      redirect_to variant_return_path(@product_variant), notice: "Product variant reactivated."
    end

    def regenerate_name
      @product_variant.update!(name: ProductNameRenderer.variant_name(@product_variant))
      record_audit!("product_variant.name_regenerated", @product_variant)
      redirect_to variant_return_path(@product_variant), notice: "Variant name regenerated."
    end

    private

    def set_product_variant
      @product_variant = ProductVariant.find(params[:id])
    end

    def load_form_collections
      @products = Product.active_records.order(:name)
      @sub_departments = SubDepartment.active_records.order(:name)
      @conditions = ProductCondition.active_records.order(:sort_order, :name)
      @display_locations = DisplayLocation.active_for_tree_select
      @vendors = Vendor.active_records.order(:name)
      @classification_defaults = @product_variant&.sub_department.present? ? ClassificationDefaultsResolver.for(variant: @product_variant) : nil
      @manage_inventory_behavior = manage_inventory_behavior?
    end

    def apply_variant_defaults!
      return if @product_variant.product.blank?

      condition = @product_variant.condition || ProductCondition.active_records.find_by(condition_key: "new")
      if @product_variant.selling_price_cents.to_i.zero?
        @product_variant.selling_price_cents = AddItem::DefaultSellingPrice.cents(
          product: @product_variant.product,
          condition: condition
        )
      end
      VariantClassificationSetup.apply!(variant: @product_variant)
    end

    def apply_tracking_sync!
      Items::InventoryTrackingSync.apply_tracking_selection!(
        variant: @product_variant,
        tracking: params.dig(:product_variant, :inventory_tracking)
      )
    end

    def legacy_behavior_changed_in_params?
      return false unless manage_inventory_behavior?
      return false if params[:product_variant].blank?

      behavior = params[:product_variant][:inventory_behavior]
      behavior.present? && behavior != @product_variant.inventory_behavior
    end

    def tracking_selection_changed?
      tracking = params.dig(:product_variant, :inventory_tracking)
      tracking.present? && tracking != @product_variant.inventory_tracking
    end

    def preview_tracking_change
      @tracking_change_preview = Items::InventoryTrackingSync.preview_legacy_behavior_edit(
        variant: @product_variant,
        inventory_behavior: params.dig(:product_variant, :inventory_behavior)
      )
    end

    def variant_return_path(variant = @product_variant)
      Items::ReturnPath.for(
        record: variant.product,
        return_to: params[:return_to].presence || "item",
        tab: "item_setup",
        variant_id: variant.id
      )
    end

    def product_variant_params
      permitted = params.require(:product_variant).permit(
        :product_id, :name, :name_override, :short_name, :sku, :condition_id, :sub_department_id,
        :display_location_id, :attribute1_value, :attribute1_sku_component, :attribute2_value,
        :attribute2_sku_component, :selling_price_cents, :pricing_model_override,
        :inventory_behavior, :inventory_tracking, :discountable, :preferred_vendor_id, :orderable, :active
      )
      permitted.delete(:inventory_behavior) unless manage_inventory_behavior?
      permitted
    end

    def manage_inventory_behavior?
      Authorization.allowed?(
        user: current_user,
        permission_key: "items.product_variants.manage_inventory_behavior"
      )
    end
  end
end
