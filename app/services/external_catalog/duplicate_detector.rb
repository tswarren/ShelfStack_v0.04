# frozen_string_literal: true

module ExternalCatalog
  class DuplicateDetector
    Result = Struct.new(:product, :catalog_item, :matched_isbn, :matched_type, keyword_init: true) do
      def duplicate?
        product.present?
      end
    end

    ISBN_TYPES = {
      isbn13: %w[isbn13 ean],
      isbn10: %w[isbn10]
    }.freeze

    def self.call(isbn13: nil, isbn10: nil)
      new(isbn13:, isbn10:).call
    end

    def initialize(isbn13: nil, isbn10: nil)
      @isbn13 = isbn13
      @isbn10 = isbn10
    end

    def call
      if @isbn13.present?
        match = find_product(@isbn13, ISBN_TYPES[:isbn13])
        return build_result(match, @isbn13, "isbn13") if match
      end

      if @isbn10.present?
        match = find_product(@isbn10, ISBN_TYPES[:isbn10])
        return build_result(match, @isbn10, "isbn10") if match
      end

      Result.new(product: nil, catalog_item: nil, matched_isbn: nil, matched_type: nil)
    end

    private

    def find_product(normalized, _types)
      product = Items::ProductIdentifierLookup.find_products_by_query(normalized).order(:id).first
      return product if product.present?

      Product.find_by(sku: normalized)
    end

    def build_result(product, matched_isbn, matched_type)
      Result.new(
        product: product,
        catalog_item: product&.catalog_item,
        matched_isbn: matched_isbn,
        matched_type: matched_type
      )
    end
  end
end
