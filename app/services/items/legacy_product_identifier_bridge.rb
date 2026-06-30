# frozen_string_literal: true

module Items
  # Transitional bridge until v0.04-2 product_identifiers.
  # Resolves legacy catalog_item_identifiers through catalog_items → products.
  class LegacyProductIdentifierBridge
    def self.primary_identifier(product)
      product.catalog_item&.primary_identifier
    end

    def self.find_products_by_identifier_query(query, active_only: true)
      normalized = query.to_s.strip.upcase
      return Product.none if normalized.blank?

      legacy_product_ids = CatalogItemIdentifier.joins(catalog_item: :products)
        .merge(active_only ? CatalogItem.active_records : CatalogItem.all)
        .where(
          "catalog_item_identifiers.normalized_identifier = :value OR catalog_item_identifiers.identifier_value ILIKE :like",
          value: normalized,
          like: normalized
        )
        .distinct
        .pluck("products.id")

      sku_product_ids = Product.where(sku: normalized).pluck(:id)

      Product.where(id: (legacy_product_ids + sku_product_ids).uniq)
    end
  end
end
