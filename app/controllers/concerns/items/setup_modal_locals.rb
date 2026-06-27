# frozen_string_literal: true

module Items
  module SetupModalLocals
    extend ActiveSupport::Concern

    private

    def catalog_setup_locals(item)
      {
        item: item,
        identifiers: item.catalog_item&.catalog_item_identifiers&.active_records
          &.order(primary_identifier: :desc, identifier_type: :asc, normalized_identifier: :asc) || [],
        external_catalog_import: item.catalog_item&.latest_external_catalog_import
      }
    end

    def selling_setup_locals(item, highlight_variant: nil)
      {
        item: item,
        variants: item.variants,
        highlight_variant: highlight_variant
      }
    end

    def display_setup_locals(item, highlight_variant: nil)
      load_display_vendor_data_for(item)
      {
        item: item,
        highlight_variant: highlight_variant,
        vendor_sourcing_gaps: @vendor_sourcing_gaps,
        variant_vendor_overrides: @variant_vendor_overrides
      }
    end

    def load_display_vendor_data_for(item)
      return if item.product.blank?

      variant_ids = item.variants.map(&:id)
      @variant_vendor_overrides = ProductVariantVendor
        .includes(:vendor, :product_variant)
        .joins(:product_variant, :vendor)
        .where(product_variant_id: variant_ids)
        .order("product_variants.sku", "vendors.name")

      return unless current_store.present?

      snapshot = VariantOperationalSnapshot.for_variants(store: current_store, variants: item.variants.to_a)
      variants_by_id = item.variants.index_by(&:id)
      @vendor_sourcing_gaps = snapshot.rows.filter_map do |variant_id, row|
        vendor = row.suggested_vendor&.vendor
        next if vendor.blank?
        next if row.sourcing_record_present

        { variant: variants_by_id[variant_id], vendor: vendor }
      end
    end

    def item_from_catalog_item_id(catalog_item_id)
      catalog_item = CatalogItem.find(catalog_item_id)
      ItemPresenter.from_catalog_item(catalog_item)
    end

    def item_from_variant(variant)
      ItemPresenter.from_product_variant(variant)
    end
  end
end
