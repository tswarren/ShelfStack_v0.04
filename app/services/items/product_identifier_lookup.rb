# frozen_string_literal: true

module Items
  class ProductIdentifierLookup
    def self.primary_identifier(product)
      product.primary_identifier
    end

    def self.find_products_by_query(normalized, active_only: true)
      return Product.none if normalized.blank?

      product_ids = product_identifier_product_ids(normalized, active_only: active_only)
      Product.where(id: product_ids.uniq)
    end

    def self.find_products_by_identifier_query(normalized, active_only: true)
      find_products_by_query(normalized, active_only: active_only)
    end

    def self.lookup_candidates(value)
      ProductIdentifierService.lookup_candidates(value)
    end

    def self.product_identifier_product_ids(normalized, active_only:)
      candidates = ProductIdentifierService.lookup_candidates(normalized)
      prefix = ProductIdentifierService.lookup_digit_prefix(normalized)
      candidates << prefix if prefix.present?
      candidates = candidates.compact.uniq
      return [] if candidates.empty?

      scope = ProductIdentifier.all
      scope = scope.merge(ProductIdentifier.active_records) if active_only
      scope.where(normalized_identifier: candidates).distinct.pluck(:product_id)
    end
    private_class_method :product_identifier_product_ids
  end
end
