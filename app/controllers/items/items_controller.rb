# frozen_string_literal: true

module Items
  class ItemsController < BaseController
    before_action -> { authorize!("items.catalog_items.view") }
    before_action :set_item_presenter

    VALID_TABS = %w[overview operations item_setup activity].freeze

    def show
      @tab = VALID_TABS.include?(params[:tab]) ? params[:tab] : "overview"
      @statuses = @item.full_statuses
      @highlight_variant = load_highlight_variant
      load_tab_data
      load_operations_presenter if @tab.in?(%w[overview operations])
      load_operations_tab_presenter if @tab == "operations"
      load_overview_presenter if @tab.in?(%w[overview operations])
      load_operational_warnings if @tab.in?(%w[overview operations])
    end

    private

    def set_item_presenter
      if params[:product_id].present?
        product = Product.with_attached_cover_image.includes(product_includes).find(params[:product_id])
        @item = ItemPresenter.from_product(product)
      elsif params[:product_variant_id].present?
        variant = ProductVariant.includes(product: product_includes).find(params[:product_variant_id])
        @item = ItemPresenter.from_product_variant(variant)
      elsif params[:catalog_item_id].present?
        catalog_item = CatalogItem.includes(products: product_includes).find(params[:catalog_item_id])
        product = catalog_item.products.active_records.order(:id).first
        if product.present?
          redirect_to items_item_path(product_id: product.id, tab: params[:tab], variant_id: params[:variant_id].presence)
          return
        end

        @item = ItemPresenter.from_catalog_item(catalog_item)
      else
        redirect_to items_root_path, alert: "Item not found."
      end
    end

    def product_includes
      {
        cover_image_attachment: :blob,
        format: {},
        store_category: {},
        default_display_location: :parent,
        product_variants: [ :display_location, :condition, :sub_department ]
      }
    end

    def load_tab_data
      case @tab
      when "overview"
        nil
      when "operations"
        nil
      when "item_setup"
        @identifiers = legacy_identifiers_for_setup
        @variants = @item.variants
        @external_catalog_import = @item.product&.latest_external_catalog_import
        load_display_vendor_data
      when "activity"
        @audit_events = merged_audit_events
        @trail_nodes = ItemDocumentTrailBuilder.for(item: @item, store: current_store)
        @ledger_entries = load_ledger_entries
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
      return if @item.product.blank?

      variant_id = params[:variant_id].presence || params[:product_variant_id].presence
      return if variant_id.blank?

      @item.variants.find_by(id: variant_id)
    end

    def load_order_quantities
      return unless current_store.present? && @item.variants.any?

      @order_quantities = Purchasing::OrderQuantityLookup.for_variants(
        store: current_store,
        variant_ids: @item.variants.map(&:id)
      )
    end

    def load_operations_presenter
      return unless current_store.present?

      @operations = ItemOperationsPresenter.new(
        item: @item,
        store: current_store,
        user: current_user
      )
    end

    def load_operations_tab_presenter
      return unless current_store.present?

      @operations_tab = ItemOperationsTabPresenter.new(
        item: @item,
        store: current_store,
        user: current_user,
        highlight_variant: @highlight_variant
      )
    end

    def load_overview_presenter
      return unless current_store.present?

      @overview = ItemOverviewPresenter.for(
        item: @item,
        store: current_store,
        user: current_user
      )
    end

    def load_operational_warnings
      return unless current_store.present?

      @operational_warnings = if @overview.present?
        @overview.warnings
      else
        Items::OperationalWarningBuilder.for_item(
          item: @item,
          store: current_store,
          user: current_user
        ).fetch(@item, [])
      end
    end

    def load_ledger_entries
      return [] unless ledger_visible? && @item.variants.any?

      InventoryLedgerEntry
        .includes(:product_variant, :inventory_posting)
        .where(store: current_store, product_variant_id: @item.variants.map(&:id))
        .order(occurred_at: :desc, id: :desc)
        .limit(50)
        .to_a
    end

    def ledger_visible?
      Authorization.allowed?(user: current_user, permission_key: "inventory.ledger.view", store: current_store)
    end

    def legacy_identifiers_for_setup
      catalog_item = @item.product&.catalog_item || @item.catalog_item
      return [] if catalog_item.blank?

      catalog_item.catalog_item_identifiers.active_records
        .order(primary_identifier: :desc, identifier_type: :asc, normalized_identifier: :asc)
    end

    def load_display_vendor_data
      return if @item.product.blank?

      variant_ids = @item.variants.map(&:id)
      @variant_vendor_overrides = ProductVariantVendor
        .includes(:vendor, :product_variant)
        .joins(:product_variant, :vendor)
        .where(product_variant_id: variant_ids)
        .order("product_variants.sku", "vendors.name")

      return unless current_store.present?

      snapshot = VariantOperationalSnapshot.for_variants(store: current_store, variants: @item.variants.to_a)
      variants_by_id = @item.variants.index_by(&:id)
      @vendor_sourcing_gaps = snapshot.rows.filter_map do |variant_id, row|
        vendor = row.suggested_vendor&.vendor
        next if vendor.blank?
        next if row.sourcing_record_present

        { variant: variants_by_id[variant_id], vendor: vendor }
      end
    end
  end
end
