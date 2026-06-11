# frozen_string_literal: true

module IngramCatalogImport
  class VariantMatcher
    def self.find_new_variant(product:)
      new(product: product).find_new_variant
    end

    def initialize(product:)
      @product = product
    end

    def find_new_variant
      condition = ProductCondition.active_records.find_by!(condition_key: "new")
      candidates = @product.product_variants.active_records
        .where(condition: condition)
        .select { |variant| variant.attribute1_value.blank? && variant.attribute2_value.blank? }

      expected_sku = SkuGenerator.preview_variant_sku(product: @product, condition: condition)
      candidates.find { |variant| variant.sku == expected_sku } || candidates.first
    end
  end
end
