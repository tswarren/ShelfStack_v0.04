# frozen_string_literal: true

module Items
  class PersistInitialProductIdentifier
    Result = Data.define(:identifier, :skipped)

    def self.call(product:, identifier_type: nil, identifier_value: nil, actor: nil, source: "catalog_intake")
      new(
        product: product,
        identifier_type: identifier_type,
        identifier_value: identifier_value,
        actor: actor,
        source: source
      ).call
    end

    def initialize(product:, identifier_type: nil, identifier_value: nil, actor: nil, source: "catalog_intake")
      @product = product
      @identifier_type = identifier_type.presence || "isbn13"
      @identifier_value = identifier_value.to_s.strip
      @actor = actor
      @source = source
    end

    def call
      return skipped_result if product.product_identifiers.active_records.reload.exists?

      identifier = if identifier_value.present?
        ProductIdentifierService.add_identifier_for_legacy_type!(
          product: product,
          identifier_type: identifier_type,
          value: identifier_value,
          primary: true,
          actor: actor,
          source: source
        )
      elsif product.sku.present?
        ProductIdentifierService.sync_from_product_sku!(product: product.reload, actor: actor, source: source)
      end

      Result.new(identifier: identifier, skipped: identifier.blank?)
    end

    private

    attr_reader :product, :identifier_type, :identifier_value, :actor, :source

    def skipped_result
      Result.new(identifier: nil, skipped: true)
    end
  end
end
