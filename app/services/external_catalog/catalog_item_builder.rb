# frozen_string_literal: true

module ExternalCatalog
  class CatalogItemBuilder
    def self.create!(candidate:, format:, actor:)
      ProductBuilder.create!(candidate:, format:, actor:)
    end

    def self.add_identifiers!(catalog_item:, candidate:, actor:)
      product = catalog_item.products.active_records.order(:id).first
      raise ArgumentError, "Catalog item has no linked product for transitional SKU assignment." if product.blank?

      ProductBuilder.assign_transitional_sku!(product:, candidate:, actor:)
      product.save!
      product
    end
  end
end
