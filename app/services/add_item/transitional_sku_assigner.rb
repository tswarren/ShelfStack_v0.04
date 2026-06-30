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
        preview = ProductIdentifierService.validation_preview(
          validation_family: identifier_type == "isbn10" ? "isbn" : "gtin",
          value: identifier_value
        )
        validation = { validation_message: preview[:message] }
        return [ normalized, validation ] if normalized.present?
      end

      [ ProductSkuGenerator.generate!, { validation_message: nil } ]
    end

    def normalize_identifier
      if identifier_type == "isbn10"
        normalized = ProductIdentifierService.validation_preview(validation_family: "isbn", value: identifier_value)[:normalized]
        return nil if normalized.blank? || normalized == "—"

        ProductIdentifierService.validation_preview(validation_family: "gtin", value: normalized)[:normalized]
      else
        family = identifier_type.to_s == "isbn10" ? "isbn" : "gtin"
        ProductIdentifierService.validation_preview(validation_family: family, value: identifier_value)[:normalized]
      end
    rescue ProductIdentifierService::IdentifierError
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

      bridge_scope = Items::ProductIdentifierLookup.find_products_by_query(sku)
      bridge_scope = bridge_scope.where.not(id: product.id) if product.persisted?
      found = bridge_scope.first
      return found if found.present?

      nil
    end
  end
end
