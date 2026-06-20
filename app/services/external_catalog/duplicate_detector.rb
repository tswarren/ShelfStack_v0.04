# frozen_string_literal: true

module ExternalCatalog
  class DuplicateDetector
    Result = Struct.new(:catalog_item, :matched_isbn, :matched_type, keyword_init: true) do
      def duplicate?
        catalog_item.present?
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
        item = find_item(@isbn13, ISBN_TYPES[:isbn13])
        return Result.new(catalog_item: item, matched_isbn: @isbn13, matched_type: "isbn13") if item
      end

      if @isbn10.present?
        item = find_item(@isbn10, ISBN_TYPES[:isbn10])
        return Result.new(catalog_item: item, matched_isbn: @isbn10, matched_type: "isbn10") if item
      end

      Result.new(catalog_item: nil, matched_isbn: nil, matched_type: nil)
    end

    private

    def find_item(normalized, types)
      CatalogItemIdentifier.active_records
        .where(identifier_type: types, normalized_identifier: normalized)
        .includes(:catalog_item)
        .first&.catalog_item
    end
  end
end
