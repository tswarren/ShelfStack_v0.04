# frozen_string_literal: true

module Items
  class ProductsController < BaseController
    before_action :set_product, only: %i[show edit update destroy inactivate reactivate regenerate_name]
    before_action -> { authorize!("items.products.view") }, only: %i[index show]
    before_action -> { authorize!("items.products.create") }, only: %i[new create]
    before_action -> { authorize!("items.products.update") }, only: %i[edit update regenerate_name]
    before_action -> { authorize!("items.products.inactivate") }, only: :inactivate
    before_action -> { authorize!("items.products.reactivate") }, only: :reactivate
    before_action -> { authorize!("items.products.delete") }, only: :destroy

    def index
      @products = Product.with_attached_cover_image.includes(:catalog_item).order(:name)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@product).limit(50)
      @variants = @product.product_variants.order(:sku)
    end

    def new
      @product = Product.new(
        active: true,
        product_type: "physical",
        variation_type: "standard",
        catalog_item_id: params[:catalog_item_id]
      )
      if params[:catalog_item_id].present?
        catalog_item = CatalogItem.find_by(id: params[:catalog_item_id])
        if catalog_item
          @product.name = ProductNameRenderer.product_name(@product)
          @product.variation_type = "conditional"
          apply_store_category_product_defaults!(@product, catalog_item)
        end
      end
      load_form_collections
    end

    def create
      @product = Product.new(product_params)
      load_form_collections
      if @product.save
        sync_identifiers_from_product_sku!
        record_audit!("product.created", @product)
        redirect_to item_return_path(@product, tab: "item_setup"), notice: "Product created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      load_form_collections
      purge_cover_image_if_requested
      previous_sku = @product.sku
      if @product.update(product_params)
        sync_identifiers_from_product_sku! if @product.sku.present? && (@product.sku != previous_sku || @product.product_identifiers.active_records.none?)
        regenerate_catalog_linked_name!
        record_audit!("product.updated", @product)
        redirect_to item_return_path(@product, tab: "item_setup"), notice: "Product updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @product.product_variants.exists?
        redirect_to item_return_path(@product, tab: "item_setup"),
                    alert: "Product cannot be deleted. Inactivate instead."
      else
        @product.destroy
        record_audit!("product.deleted", @product)
        redirect_to items_products_path, notice: "Product deleted."
      end
    end

    def inactivate
      @product.inactivate!
      record_audit!("product.inactivated", @product)
      redirect_to item_return_path(@product, tab: "item_setup"), notice: "Product inactivated."
    end

    def reactivate
      @product.reactivate!
      record_audit!("product.reactivated", @product)
      redirect_to item_return_path(@product, tab: "item_setup"), notice: "Product reactivated."
    end

    def regenerate_name
      @product.update!(name: ProductNameRenderer.product_name(@product))
      record_audit!("product.name_regenerated", @product)
      redirect_to item_return_path(@product, tab: "item_setup"), notice: "Product name regenerated."
    end

    private

    def set_product
      @product = Product.with_attached_cover_image.find(params[:id])
    end

    def purge_cover_image_if_requested
      return unless params.dig(:product, :remove_cover_image) == "1"

      @product.cover_image.purge
    end

    def load_form_collections
      @catalog_items = CatalogItem.active_records.includes(:format).order(:title)
      @display_locations = DisplayLocation.active_for_tree_select
      @sub_departments = SubDepartment.active_records.order(:name)
      @vendors = Vendor.active_records.order(:name)
    end

    def apply_store_category_product_defaults!(product, catalog_item = product.catalog_item)
      defaults = StoreCategoryDefaults.for(store_category_node: catalog_item&.store_category)
      return if defaults.source == "none"

      product.default_sub_department ||= defaults.default_sub_department if defaults.default_sub_department.present?
      product.default_display_location ||= defaults.default_display_location if defaults.default_display_location.present?
    end

    def regenerate_catalog_linked_name!
      return if @product.catalog_item.blank?

      @product.update!(name: ProductNameRenderer.product_name(@product))
    end

    def sync_identifiers_from_product_sku!
      ProductIdentifierService.sync_from_product_sku!(product: @product.reload, actor: current_user)
    rescue ProductIdentifierService::IdentifierError => e
      Rails.logger.warn("product sku identifier sync skipped: #{e.message}")
    end

    def product_params
      permitted = params.require(:product).permit(
        :catalog_item_id, :name, :name_override, :short_name, :sku, :product_type, :variation_type,
        :list_price_cents, :default_display_location_id, :default_sub_department_id,
        :preferred_vendor_id,
        :variant1_label, :variant2_label, :discountable, :active, :cover_image
      )

      if catalog_linked_product?
        excluded = %w[name]
        excluded << "catalog_item_id" if action_name == "update"
        permitted.except(*excluded)
      elsif action_name == "update" && @product.catalog_item_id.blank?
        permitted.except("catalog_item_id")
      else
        permitted
      end
    end

    def catalog_linked_product?
      if @product&.catalog_item_id.present?
        true
      elsif action_name == "create"
        params.dig(:product, :catalog_item_id).present?
      else
        false
      end
    end
  end
end
