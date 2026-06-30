# frozen_string_literal: true

module IngramCatalogImport
  class ProductResolver
    Result = Struct.new(:product, :status, :message, keyword_init: true) do
      def found?
        product.present?
      end

      def needs_create?
        status == :missing
      end

      def ambiguous?
        status == :ambiguous
      end
    end

    def self.resolve(catalog_item:)
      new(catalog_item: catalog_item).resolve
    end

    def initialize(catalog_item:)
      @catalog_item = catalog_item
    end

    def resolve
      products = Product.active_records.where(catalog_item: @catalog_item).to_a
      return Result.new(status: :missing) if products.empty?

      primary_sku = products.filter_map { |product| product.primary_identifier&.normalized_identifier }.first
      primary_sku ||= @catalog_item.primary_identifier&.normalized_identifier
      primary_sku ||= products.first&.sku
      sku_matches = primary_sku.present? ? products.select { |product| product.sku == primary_sku } : []
      candidates = sku_matches.presence || products
      conditional_matches = candidates.select { |product| product.variation_type == "conditional" }

      if conditional_matches.size == 1
        return Result.new(product: conditional_matches.first, status: :found)
      end

      if conditional_matches.size > 1
        return Result.new(status: :ambiguous, message: "Multiple conditional products found for catalog item")
      end

      if candidates.size == 1
        return Result.new(product: candidates.first, status: :found)
      end

      Result.new(status: :ambiguous, message: "Multiple products found for catalog item")
    end
  end
end
