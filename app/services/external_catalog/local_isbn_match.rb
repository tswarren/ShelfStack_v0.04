# frozen_string_literal: true

module ExternalCatalog
  class LocalIsbnMatch
    Result = Struct.new(:catalog_item, :normalized_isbn, keyword_init: true) do
      def matched?
        catalog_item.present?
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
      return Result.new(catalog_item: nil, normalized_isbn: normalized) if normalized.blank?

      resolution = IngramCatalogImport::IdentifierResolver.resolve(product_code: @isbn, ean: @isbn)
      catalog_item = resolution.conflict? ? nil : resolution.catalog_item
      Result.new(catalog_item: catalog_item, normalized_isbn: normalized)
    end

    private

    def normalize(value)
      CatalogIdentifierService.normalize_preview("isbn13", value)
    rescue CatalogIdentifierService::IdentifierError
      nil
    end
  end
end
