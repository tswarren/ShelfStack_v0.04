# frozen_string_literal: true

module IngramCatalogImport
  class IdentifierResolver
    Result = Struct.new(:catalog_item, :status, :message, keyword_init: true) do
      def found?
        catalog_item.present?
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
      ean_item = find_catalog_item(@ean, EAN_TYPES)
      product_code_item = find_catalog_item(@product_code, PRODUCT_CODE_TYPES)

      if ean_item && product_code_item && ean_item.id != product_code_item.id
        return Result.new(
          status: :conflict,
          message: "EAN and Product Code resolve to different catalog items"
        )
      end

      Result.new(
        catalog_item: ean_item || product_code_item,
        status: (ean_item || product_code_item) ? :found : :missing
      )
    end

    def self.find_catalog_item(value, identifier_types)
      normalized = normalize(value, identifier_types)
      return nil if normalized.blank?

      product = Items::ProductIdentifierLookup.find_products_by_query(normalized).order(:id).first
      product&.catalog_item
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

    def find_catalog_item(value, identifier_types)
      self.class.find_catalog_item(value, identifier_types)
    end
  end
end
