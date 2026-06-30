# frozen_string_literal: true

module IngramCatalogImport
  class IdentifierResolver
    Match = Struct.new(:product, :catalog_item, keyword_init: true)

    Result = Struct.new(:product, :catalog_item, :status, :message, keyword_init: true) do
      def found?
        product.present?
      end

      def conflict?
        status == :conflict
      end
    end

    EAN_TYPES = %w[isbn13 ean gtin].freeze
    PRODUCT_CODE_TYPES = %w[isbn10 isbn].freeze

    def self.resolve(product_code:, ean:)
      new(product_code: product_code, ean: ean).resolve
    end

    def initialize(product_code:, ean:)
      @product_code = product_code
      @ean = ean
    end

    def resolve
      ean_match = find_match(@ean, EAN_TYPES)
      product_code_match = find_match(@product_code, PRODUCT_CODE_TYPES)

      if ean_match && product_code_match && ean_match.product.id != product_code_match.product.id
        return Result.new(
          status: :conflict,
          message: "EAN and Product Code resolve to different products"
        )
      end

      match = ean_match || product_code_match
      Result.new(
        product: match&.product,
        catalog_item: match&.catalog_item,
        status: match ? :found : :missing
      )
    end

    def self.find_match(value, identifier_types)
      normalized = normalize(value, identifier_types)
      return nil if normalized.blank?

      product = Items::ProductIdentifierLookup.find_products_by_query(normalized).order(:id).first
      return nil unless product

      Match.new(product: product, catalog_item: product.catalog_item)
    end

    def self.normalize(value, identifier_types)
      return nil if value.blank?

      preview = if identifier_types.include?("isbn10") || identifier_types.include?("isbn")
        ProductIdentifierService.validation_preview(validation_family: "isbn", value: value)
      else
        ProductIdentifierService.validation_preview(validation_family: "gtin", value: value)
      end
      normalized = preview[:normalized]
      return nil if normalized.blank? || normalized == "—"

      normalized
    end
    private_class_method :normalize

    private

    def find_match(value, identifier_types)
      self.class.find_match(value, identifier_types)
    end
  end
end
