# frozen_string_literal: true

module Items
  class ItemsController < BaseController
    before_action -> { authorize!("items.catalog_items.view") }
    before_action :set_item_presenter

    VALID_TABS = %w[overview catalog selling display activity].freeze

    def show
      @tab = VALID_TABS.include?(params[:tab]) ? params[:tab] : "overview"
      @statuses = @item.full_statuses
      @highlight_variant = load_highlight_variant
      load_tab_data
    end

    private

    def set_item_presenter
      if params[:catalog_item_id].present?
        catalog_item = CatalogItem.includes(products: product_includes).find(params[:catalog_item_id])
        @item = ItemPresenter.from_catalog_item(catalog_item)
      elsif params[:product_id].present?
        product = Product.with_attached_cover_image.includes(:catalog_item, product_includes).find(params[:product_id])
        @item = ItemPresenter.from_product(product)
      else
        redirect_to items_root_path, alert: "Item not found."
      end
    end

    def product_includes
      {
        cover_image_attachment: :blob,
        default_display_location: :parent,
        product_variants: [:display_location, :condition, :category, { categorizations: { category_node: :parent } }]
      }
    end

    def load_tab_data
      case @tab
      when "catalog"
        @identifiers = @item.catalog_item&.catalog_item_identifiers&.active_records
          &.order(primary_identifier: :desc, identifier_type: :asc, normalized_identifier: :asc) || []
      when "selling"
        @variants = @item.variants
      when "activity"
        @audit_events = merged_audit_events
      end
    end

    def merged_audit_events
      records = []
      records << @item.catalog_item if @item.catalog_item
      records << @item.product if @item.product
      records.concat(@item.variants.to_a)

      records.flat_map { |record| AuditEvent.for_auditable(record).limit(20) }
        .sort_by(&:occurred_at)
        .reverse
        .first(50)
    end

    def load_highlight_variant
      return if params[:variant_id].blank? || @item.product.blank?

      @item.variants.find_by(id: params[:variant_id])
    end
  end
end
