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
      @product.product_variants.active_records
        .where(condition: condition)
        .find { |variant| variant.attribute1_value.blank? && variant.attribute2_value.blank? }
    end
  end
end
