# frozen_string_literal: true

module Items
  class AddItemController < BaseController
    STEPS = %w[identify type catalog_details selling_setup sellable_sku].freeze

    before_action -> { authorize!("items.catalog_items.create") }
    before_action :load_step
    before_action :load_draft

    def new
      reset_draft!
      redirect_to items_add_item_path(step: "identify")
    end

    def create
      case @step
      when "identify" then handle_identify
      when "type" then handle_type
      when "catalog_details" then handle_catalog_details
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
      @step = params[:step].presence || "identify"
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

    def render_step
      case @step
      when "identify"
        @query = params[:q].to_s.strip
        @results = ItemSearch.call(query: @query) if @query.present?
      when "type"
        redirect_to items_add_item_path(step: "identify"), alert: "Identify an item first." if @draft["catalog_item_id"].blank? && @draft["new_item"].blank?
      when "catalog_details"
        @catalog_item = find_or_build_catalog_item
        @formats = Format.active_records.order(:name)
      when "selling_setup"
        @catalog_item = CatalogItem.find(@draft["catalog_item_id"])
        @product = Product.new(catalog_item: @catalog_item, active: true, product_type: "physical", variation_type: "standard")
        load_product_collections
      when "sellable_sku"
        @product = Product.find(@draft["product_id"])
        @variant = ProductVariant.new(product: @product, active: true, inventory_behavior: "standard_physical")
        load_variant_collections
      end

      render "items/add_item/#{@step}"
    end

    def handle_identify
      if params[:create_new].present?
        save_draft!("new_item" => true, "query" => params[:q].to_s.strip)
        redirect_to items_add_item_path(step: "type")
        return
      end

      @query = params[:q].to_s.strip
      @results = ItemSearch.call(query: @query) if @query.present?
      @step = "identify"
      render "items/add_item/identify"
    end

    def handle_type
      save_draft!("catalog_item_type" => params.require(:catalog_item_type))
      redirect_to items_add_item_path(step: "catalog_details")
    end

    def handle_catalog_details
      @formats = Format.active_records.order(:name)
      @catalog_item = CatalogItem.new(catalog_item_params.merge(active: true, publication_status: "active"))
      saved = false

      CatalogItem.transaction do
        raise ActiveRecord::Rollback unless @catalog_item.save

        if identifier_value_param.present?
          CatalogIdentifierService.add_identifier!(
            catalog_item: @catalog_item,
            identifier_type: identifier_type_param,
            value: identifier_value_param,
            primary: true,
            actor: current_user
          )
        else
          CatalogIdentifierService.generate_local!(catalog_item: @catalog_item, actor: current_user)
        end

        saved = @catalog_item.reload.primary_identifier.present?
        raise ActiveRecord::Rollback unless saved
      end

      if saved
        record_audit!("catalog_item.created", @catalog_item)
        save_draft!("catalog_item_id" => @catalog_item.id)
        redirect_to items_add_item_path(step: "selling_setup")
      else
        @step = "catalog_details"
        render "items/add_item/catalog_details", status: :unprocessable_entity
      end
    rescue CatalogIdentifierService::IdentifierError => e
      @catalog_item.errors.add(:base, e.message)
      @step = "catalog_details"
      render "items/add_item/catalog_details", status: :unprocessable_entity
    end

    def handle_selling_setup
      @catalog_item = CatalogItem.find(@draft["catalog_item_id"])
      @product = Product.new(product_params.merge(catalog_item: @catalog_item, active: true, product_type: "physical", variation_type: "standard"))
      load_product_collections

      if @product.save
        record_audit!("product.created", @product)
        save_draft!("product_id" => @product.id)
        redirect_to items_add_item_path(step: "sellable_sku")
      else
        @step = "selling_setup"
        render "items/add_item/selling_setup", status: :unprocessable_entity
      end
    end

    def handle_sellable_sku
      @product = Product.find(@draft["product_id"])
      @variant = ProductVariant.new(product_variant_params.merge(product: @product, active: true, inventory_behavior: "standard_physical"))
      load_variant_collections

      if @variant.save
        record_audit!("product_variant.created", @variant, details: { "sku" => @variant.sku })
        reset_draft!
        redirect_to ItemPresenter.from_product(@product).show_path, notice: "Item added successfully."
      else
        @step = "sellable_sku"
        render "items/add_item/sellable_sku", status: :unprocessable_entity
      end
    end

    def find_or_build_catalog_item
      if @draft["catalog_item_id"].present?
        CatalogItem.find(@draft["catalog_item_id"])
      else
        CatalogItem.new(
          catalog_item_type: @draft["catalog_item_type"] || "book",
          active: true,
          publication_status: "active"
        )
      end
    end

    def load_product_collections
      @display_locations = DisplayLocation.active_records.order(:sort_order, :name)
    end

    def load_variant_collections
      @categories = Category.active_records.includes(:department).order("departments.department_number", :name)
      @conditions = ProductCondition.active_records.order(:sort_order, :name)
      @display_locations = DisplayLocation.active_records.order(:sort_order, :name)
      @variant.condition ||= ProductCondition.find_by(condition_key: "new")
      @variant.category ||= @categories.first
    end

    def catalog_item_params
      params.require(:catalog_item).permit(
        :catalog_item_type, :title, :creators, :publisher, :publication_date, :publication_status,
        :series_name, :series_enumeration, :format_id, :edition_statement, :language_code,
        :height, :width, :depth, :dimension_units, :weight, :weight_units, :page_count,
        :duration_minutes, :large_print, :bisac_subjects, :genres, :themes, :target_audiences,
        :access_restrictions, :publication_frequency, :description, :year, :digital, :active
      )
    end

    def product_params
      params.require(:product).permit(:name, :sku, :list_price_cents, :default_display_location_id)
    end

    def product_variant_params
      params.require(:product_variant).permit(
        :condition_id, :category_id, :selling_price_cents, :display_location_id, :sku
      )
    end

    def identifier_type_param
      params.dig(:catalog_item, :initial_identifier_type).presence || "isbn13"
    end

    def identifier_value_param
      params.dig(:catalog_item, :initial_identifier_value).to_s.strip
    end
  end
end
