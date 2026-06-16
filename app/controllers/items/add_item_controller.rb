# frozen_string_literal: true

module Items
  class AddItemController < BaseController
    include CatalogItemBisacSyncable

    STEPS = %w[choose_path item_details selling_setup sellable_sku].freeze
    WORKFLOWS = %w[catalog_linked non_catalog].freeze

    before_action :load_step
    before_action :load_draft
    before_action :authorize_step!

    def new
      reset_draft!
      redirect_to items_add_item_path(step: "choose_path")
    end

    def create
      case @step
      when "choose_path" then handle_choose_path
      when "item_details" then handle_item_details
      when "selling_setup" then handle_selling_setup
      when "sellable_sku" then handle_sellable_sku
      else
        redirect_to items_root_path, alert: "Unknown wizard step."
      end
    end

    def show
      render_step
    end

    private

    def load_step
      @step = params[:step].presence || "choose_path"
      redirect_to items_root_path, alert: "Unknown wizard step." unless STEPS.include?(@step)
    end

    def load_draft
      @draft = session[:add_item_draft] ||= {}
    end

    def reset_draft!
      session[:add_item_draft] = {}
    end

    def save_draft!(attrs)
      session[:add_item_draft] = @draft.merge(attrs.stringify_keys)
      @draft = session[:add_item_draft]
    end

    def authorize_step!
      case @step
      when "choose_path"
        authorize!("items.access")
      when "item_details"
        authorize!("items.catalog_items.create")
      when "selling_setup"
        authorize!("items.products.create")
      when "sellable_sku"
        authorize!("items.product_variants.create")
      end
    end

    def catalog_linked?
      @draft["workflow"] == "catalog_linked"
    end

    def non_catalog?
      @draft["workflow"] == "non_catalog"
    end

    def render_step
      case @step
      when "choose_path"
        render "items/add_item/choose_path"
      when "item_details"
        ensure_catalog_linked_workflow! or return
        @catalog_item = find_or_build_catalog_item
        @formats = Format.active_records.order(:name)
        load_bisac_form_state(@catalog_item)
        load_store_category_collections
        render "items/add_item/item_details"
      when "selling_setup"
        if params[:generate_sku].present?
          save_draft!("generated_sku" => AddItem::ProductSkuGenerator.generate!)
          redirect_to items_add_item_path(step: "selling_setup") and return
        end
        if catalog_linked?
          ensure_catalog_item_in_draft! or return
        else
          ensure_non_catalog_workflow! or return
        end
        prepare_selling_setup_form
        render "items/add_item/selling_setup"
      when "sellable_sku"
        ensure_product_in_draft! or return
        @product = Product.find(@draft["product_id"])
        prepare_sellable_sku_form
        render "items/add_item/sellable_sku"
      end
    end

    def handle_choose_path
      workflow = params.require(:workflow)
      unless WORKFLOWS.include?(workflow)
        redirect_to items_add_item_path(step: "choose_path"), alert: "Choose a valid item type."
        return
      end

      save_draft!("workflow" => workflow)
      if workflow == "catalog_linked"
        redirect_to items_add_item_path(step: "item_details")
      else
        redirect_to items_add_item_path(step: "selling_setup")
      end
    end

    def handle_item_details
      ensure_catalog_linked_workflow! or return
      @formats = Format.active_records.order(:name)
      load_store_category_collections
      @catalog_item = CatalogItem.new(catalog_item_params.merge(active: true, publication_status: "active"))

      saved = save_catalog_item!(@catalog_item)
      return unless saved

      bisac_result = sync_catalog_item_bisac!(@catalog_item)
      store_category_result = sync_catalog_store_category!(@catalog_item)
      record_audit!("catalog_item.created", @catalog_item)
      apply_bisac_sync_notice!(bisac_result)
      apply_store_category_sync_notice!(store_category_result)
      apply_identifier_validation_notice!(@catalog_item)
      save_draft!("catalog_item_id" => @catalog_item.id)

      if done_commit?
        reset_draft!
        redirect_to ItemPresenter.from_catalog_item(@catalog_item).show_path,
                    notice: "Item details saved. Status: Catalog Only."
      else
        redirect_to items_add_item_path(step: "selling_setup")
      end
    rescue CatalogIdentifierService::IdentifierError => e
      @catalog_item.errors.add(:base, e.message)
      @step = "item_details"
      load_bisac_form_state(@catalog_item)
      load_store_category_collections
      render "items/add_item/item_details", status: :unprocessable_entity
    end

    def handle_selling_setup
      if params[:generate_sku].present?
        ensure_non_catalog_workflow! or return
        save_draft!("generated_sku" => AddItem::ProductSkuGenerator.generate!)
        redirect_to items_add_item_path(step: "selling_setup")
        return
      end

      if catalog_linked?
        ensure_catalog_item_in_draft! or return
      else
        ensure_non_catalog_workflow! or return
      end

      @product = build_product_from_params
      load_product_collections
      @catalog_item = @product.catalog_item if catalog_linked?

      if @product.save
        record_audit!("product.created", @product)
        save_draft!("product_id" => @product.id)

        if done_commit?
          reset_draft!
          redirect_to ItemPresenter.from_product(@product).show_path,
                      notice: "Selling setup saved. Add a sellable SKU when ready."
        else
          redirect_to items_add_item_path(step: "sellable_sku")
        end
      else
        @step = "selling_setup"
        load_product_collections
        @catalog_item = @product.catalog_item if catalog_linked?
        render "items/add_item/selling_setup", status: :unprocessable_entity
      end
    end

    def handle_sellable_sku
      ensure_product_in_draft!
      @product = Product.find(@draft["product_id"])
      inventory_behavior = AddItem::InventoryBehaviorMapper.for_product_type(@product.product_type)
      @variant = ProductVariant.new(
        product_variant_params.merge(
          product: @product,
          active: true,
          inventory_behavior: inventory_behavior
        )
      )
      @variant.condition ||= default_condition
      VariantClassificationSetup.apply!(variant: @variant)
      prepare_sellable_sku_form

      if @variant.save
        record_audit!("product_variant.created", @variant, details: { "sku" => @variant.sku })

        if add_another_commit?
          redirect_to items_add_item_path(step: "sellable_sku"),
                      notice: "Sellable SKU created. Add another or cancel to finish."
        else
          reset_draft!
          redirect_to ItemPresenter.from_product(@product).show_path, notice: "Item added successfully."
        end
      else
        @step = "sellable_sku"
        render "items/add_item/sellable_sku", status: :unprocessable_entity
      end
    end

    def save_catalog_item!(catalog_item)
      saved = false
      CatalogItem.transaction do
        raise ActiveRecord::Rollback unless catalog_item.save

        if identifier_value_param.present?
          CatalogIdentifierService.add_identifier!(
            catalog_item: catalog_item,
            identifier_type: identifier_type_param,
            value: identifier_value_param,
            primary: true,
            actor: current_user
          )
        else
          CatalogIdentifierService.generate_local!(catalog_item: catalog_item, actor: current_user)
        end

        saved = catalog_item.reload.primary_identifier.present?
        raise ActiveRecord::Rollback unless saved
      end

      unless saved
        @step = "item_details"
        load_bisac_form_state(catalog_item)
        load_store_category_collections
        render "items/add_item/item_details", status: :unprocessable_entity
      end

      saved
    end

    def prepare_selling_setup_form
      load_product_collections

      if catalog_linked?
        ensure_catalog_item_in_draft!
        @catalog_item = CatalogItem.find(@draft["catalog_item_id"])
        @product = Product.new(
          catalog_item: @catalog_item,
          active: true,
          product_type: "physical",
          variation_type: "conditional",
          name: ProductNameRenderer.product_name(Product.new(catalog_item: @catalog_item)),
          sku: @catalog_item.primary_identifier&.normalized_identifier,
          list_price_cents: 0
        )
        apply_store_category_product_defaults!(@product)
      else
        ensure_non_catalog_workflow!
        @catalog_item = nil
        @product = Product.new(
          active: true,
          product_type: "physical",
          variation_type: "standard",
          sku: @draft["generated_sku"],
          list_price_cents: 0
        )
      end
    end

    def build_product_from_params
      attrs = product_params.to_h.symbolize_keys
      attrs[:active] = true

      if catalog_linked?
        @catalog_item = CatalogItem.find(@draft["catalog_item_id"])
        attrs[:catalog_item] = @catalog_item
        attrs[:variation_type] = resolved_variation_type(attrs[:product_type], attrs[:variation_type].presence || "conditional")
        attrs.delete(:name)
        apply_store_category_product_defaults!(attrs)
      else
        attrs[:variation_type] = resolved_variation_type(attrs[:product_type], attrs[:variation_type])
        attrs.delete(:name_override)
      end

      Product.new(attrs)
    end

    def apply_store_category_product_defaults!(target)
      defaults = StoreCategoryDefaults.for(store_category_node: @catalog_item&.store_category)
      return if defaults.source == "none"

      if target.is_a?(Hash)
        if defaults.default_sub_department.present? && target[:default_sub_department_id].blank?
          target[:default_sub_department_id] = defaults.default_sub_department.id
        end
        if defaults.default_display_location.present? && target[:default_display_location_id].blank?
          target[:default_display_location_id] = defaults.default_display_location.id
        end
      else
        target.default_sub_department ||= defaults.default_sub_department if defaults.default_sub_department.present?
        target.default_display_location ||= defaults.default_display_location if defaults.default_display_location.present?
      end
    end

    def resolved_variation_type(product_type, variation_type)
      return "standard" if product_type.in?(%w[service financial non_inventory])

      variation_type.presence || "standard"
    end

    def prepare_sellable_sku_form
      load_variant_collections
      @variant ||= ProductVariant.new(product: @product, active: true)
      condition = @variant.condition || default_condition
      @variant.condition_id ||= condition&.id
      @variant.condition ||= condition
      @variant.sub_department_id ||= @product.default_sub_department_id.presence || @sub_departments.first&.id
      @variant.inventory_behavior ||= AddItem::InventoryBehaviorMapper.for_product_type(@product.product_type)
      VariantClassificationSetup.apply!(variant: @variant) unless sellable_sku_params_submitted?
      apply_variant_defaults! unless sellable_sku_params_submitted?
    end

    def sellable_sku_params_submitted?
      params[:product_variant].present?
    end

    def apply_variant_defaults!
      condition = @variant.condition || default_condition
      if @variant.selling_price_cents.to_i.zero?
        @variant.selling_price_cents = AddItem::DefaultSellingPrice.cents(product: @product, condition: condition)
      end
    end

    def default_condition
      ProductCondition.active_records.find_by(new_condition: true) ||
        ProductCondition.active_records.order(:sort_order).first
    end

    def find_or_build_catalog_item
      if @draft["catalog_item_id"].present?
        CatalogItem.find(@draft["catalog_item_id"])
      else
        CatalogItem.new(active: true, publication_status: "active", catalog_item_type: "book")
      end
    end

    def ensure_catalog_linked_workflow!
      return true if catalog_linked?

      redirect_to items_add_item_path(step: "choose_path"), alert: "Choose catalog-linked item to continue."
      false
    end

    def ensure_non_catalog_workflow!
      return true if non_catalog?

      redirect_to items_add_item_path(step: "choose_path"), alert: "Choose non-catalog item to continue."
      false
    end

    def ensure_catalog_item_in_draft!
      return true if @draft["catalog_item_id"].present?

      redirect_to items_add_item_path(step: "item_details"), alert: "Complete item details first."
      false
    end

    def ensure_product_in_draft!
      return true if @draft["product_id"].present?

      redirect_to items_add_item_path(step: "selling_setup"), alert: "Complete selling setup first."
      false
    end

    def load_store_category_collections
      @store_category_scheme = CategoryScheme.active_records.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      @store_category_nodes = if @store_category_scheme
                                CategoryNode.active_for_tree_select(@store_category_scheme)
      else
                                CategoryNode.none
      end
    end

    def load_product_collections
      @sub_departments = SubDepartment.active_records.order(:name)
      @display_locations = DisplayLocation.active_for_tree_select
    end

    def load_variant_collections
      load_product_collections
      @conditions = ProductCondition.active_records.order(:sort_order, :name)
    end

    def catalog_item_params
      params.require(:catalog_item).permit(
        :catalog_item_type, :title, :creators, :publisher, :publication_date, :publication_status,
        :series_name, :series_enumeration, :format_id, :edition_statement, :language_code,
        :height, :width, :depth, :dimension_units, :weight, :weight_units, :page_count,
        :duration_minutes, :large_print, :bisac_subjects, :genres, :themes, :target_audiences,
        :access_restrictions, :publication_frequency, :description, :year, :digital, :active,
        :store_category_id
      )
    end

    def product_params
      params.require(:product).permit(
        :name, :name_override, :sku, :product_type, :variation_type, :list_price_cents,
        :default_display_location_id, :default_sub_department_id, :variant1_label, :variant2_label,
        :cover_image
      )
    end

    def product_variant_params
      params.require(:product_variant).permit(
        :condition_id, :sub_department_id, :selling_price_cents, :display_location_id, :sku,
        :name_override, :attribute1_value, :attribute1_sku_component,
        :attribute2_value, :attribute2_sku_component
      )
    end

    def sync_catalog_store_category!(catalog_item)
      CatalogItemStoreCategorySync.apply!(
        catalog_item: catalog_item,
        store_category_id: params.dig(:catalog_item, :store_category_id),
        bisac_category_node_ids: params[:bisac_category_node_ids]
      )
    end

    def apply_store_category_sync_notice!(result)
      return if result.warnings.blank?

      flash.now[:alert] = [ flash.now[:alert], result.warnings.join(" ") ].compact.join(" ")
    end

    def identifier_type_param
      params.dig(:catalog_item, :initial_identifier_type).presence || "isbn13"
    end

    def identifier_value_param
      params.dig(:catalog_item, :initial_identifier_value).to_s.strip
    end

    def done_commit?
      params[:commit].to_s.casecmp("done").zero?
    end

    def add_another_commit?
      params[:commit].to_s.include?("Add Another")
    end
  end
end
