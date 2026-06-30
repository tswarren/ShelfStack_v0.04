# frozen_string_literal: true

module ExternalCatalog
  class LocalIsbnMatch
    Result = Struct.new(:product, :normalized_isbn, keyword_init: true) do
      def matched?
        product.present?
      end
    end

    def self.call(isbn:)
      new(isbn:).call
    end

    def initialize(isbn:)
      @isbn = isbn
    end

    def call
      normalized = normalize(@isbn)
      return Result.new(product: nil, normalized_isbn: normalized) if normalized.blank?

      product = Product.find_by(sku: normalized)
      product ||= Items::ProductIdentifierLookup.find_products_by_identifier_query(normalized).order(:id).first
      unless product
        resolution = IngramCatalogImport::IdentifierResolver.resolve(product_code: @isbn, ean: @isbn)
        unless resolution.conflict?
          product = resolution.catalog_item&.products&.active_records&.order(:id)&.first
        end
      end

      Result.new(product: product, normalized_isbn: normalized)
    end

    private

    def normalize(value)
      ProductIdentifierService.normalize_preview("isbn13", value)
    rescue ProductIdentifierService::IdentifierError
      nil
    end
  end
end
