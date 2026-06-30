# frozen_string_literal: true

module AddItem
  class TransitionalSkuAssigner
    class ConflictError < StandardError; end

    Result = Data.define(:sku, :validation_message, :normalized_identifier)

    def self.assign!(product:, identifier_type: nil, identifier_value: nil, candidate: nil, actor: nil)
      new(
        product: product,
        identifier_type: identifier_type,
        identifier_value: identifier_value,
        candidate: candidate,
        actor: actor
      ).assign!
    end

    def initialize(product:, identifier_type: nil, identifier_value: nil, candidate: nil, actor: nil)
      @product = product
      @identifier_type = identifier_type.presence || "isbn13"
      @identifier_value = identifier_value.to_s.strip.presence
      @candidate = candidate
      @actor = actor
    end

    def assign!
      sku, validation = resolve_sku_and_validation
      ensure_unique!(sku)
      @product.sku = sku
      Result.new(sku: sku, validation_message: validation[:validation_message], normalized_identifier: sku)
    end

    private

    attr_reader :product, :identifier_type, :identifier_value, :candidate, :actor

    def resolve_sku_and_validation
      if candidate.present?
        normalized = candidate.isbn13.presence || candidate.isbn10.presence
        return [ normalized, { validation_message: nil } ] if normalized.present?
      end

      if identifier_value.present?
        normalized = normalize_identifier
        preview = CatalogIdentifierService.validation_preview(identifier_type: identifier_type, value: identifier_value)
        validation = { validation_message: preview[:message] }
        return [ normalized, validation ] if normalized.present?
      end

      [ ProductSkuGenerator.generate!, { validation_message: nil } ]
    end

    def normalize_identifier
      if identifier_type == "isbn10"
        normalized = CatalogIdentifierService.normalize_preview("isbn10", identifier_value)
        CatalogIdentifierService.normalize_preview("isbn13", normalized) if normalized.present?
      else
        CatalogIdentifierService.normalize_preview(identifier_type, identifier_value)
      end
    rescue CatalogIdentifierService::IdentifierError
      nil
    end

    def ensure_unique!(sku)
      conflicting = find_conflicting_product(sku)
      return if conflicting.blank?

      title = conflicting.display_title
      raise ConflictError, "Identifier #{sku} is already assigned to \"#{title}\"."
    end

    def find_conflicting_product(sku)
      match = Product.where(sku: sku)
      match = match.where.not(id: product.id) if product.persisted?
      found = match.first
      return found if found.present?

      bridge_scope = Items::LegacyProductIdentifierBridge.find_products_by_identifier_query(sku)
      bridge_scope = bridge_scope.where.not(id: product.id) if product.persisted?
      found = bridge_scope.first
      return found if found.present?

      legacy_identifier = CatalogItemIdentifier.active_records
        .where(normalized_identifier: sku)
        .includes(:catalog_item)
        .first
      return nil if legacy_identifier.blank?

      legacy_product = legacy_identifier.catalog_item.products.active_records.order(:id).first
      return legacy_product if legacy_product.present? && (!product.persisted? || legacy_product.id != product.id)

      raise ConflictError, "Identifier #{sku} is already assigned to \"#{legacy_identifier.catalog_item.title}\"."
    end
  end
end
