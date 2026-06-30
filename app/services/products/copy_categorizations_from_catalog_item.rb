# frozen_string_literal: true

module Products
  class CopyCategorizationsFromCatalogItem
    def self.to_product(product, catalog_item)
      new(product: product, catalog_item: catalog_item).copy_catalog_to_product
    end

    def self.sync_product_and_catalog(product, catalog_item)
      new(product: product, catalog_item: catalog_item).sync_bidirectional
    end

    def initialize(product:, catalog_item:)
      @product = product
      @catalog_item = catalog_item
    end

    def copy_catalog_to_product
      categorizations_for(@catalog_item).find_each do |cat|
        copy_categorization(to: @product, from: cat)
      end
      @product
    end

    def sync_bidirectional
      categorizations_for(@product).find_each do |cat|
        copy_categorization(to: @catalog_item, from: cat)
      end

      categorizations_for(@catalog_item).find_each do |cat|
        copy_categorization(to: @product, from: cat)
      end

      @product
    end

    private

    def categorizations_for(record)
      Categorization.where(categorizable_type: record.class.name, categorizable_id: record.id)
    end

    def copy_categorization(to:, from:)
      Categorization.find_or_create_by!(
        categorizable: to,
        category_node_id: from.category_node_id
      ) do |new_cat|
        new_cat.primary = from.primary
        new_cat.source = from.source
      end
    end
  end
end
