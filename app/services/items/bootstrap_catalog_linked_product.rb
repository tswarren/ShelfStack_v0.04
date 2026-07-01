# frozen_string_literal: true

module Items
  class BootstrapCatalogLinkedProduct
    Result = Data.define(:product, :sku_validation_message, :identifier)

    def self.call(catalog_item:, identifier_type: nil, identifier_value: nil, actor: nil)
      new(
        catalog_item: catalog_item,
        identifier_type: identifier_type,
        identifier_value: identifier_value,
        actor: actor
      ).call
    end

    def initialize(catalog_item:, identifier_type: nil, identifier_value: nil, actor: nil)
      @catalog_item = catalog_item
      @identifier_type = identifier_type.presence || "isbn13"
      @identifier_value = identifier_value.to_s.strip
      @actor = actor
    end

    def call
      Product.transaction do
        product = build_product
        sku_result = AddItem::TransitionalSkuAssigner.assign!(
          product: product,
          identifier_type: identifier_type,
          identifier_value: identifier_value,
          actor: actor
        )
        product.save!
        identifier_result = PersistInitialProductIdentifier.call(
          product: product,
          identifier_type: identifier_type,
          identifier_value: identifier_value,
          actor: actor,
          source: "catalog_item_create"
        )

        Result.new(
          product: product,
          sku_validation_message: sku_result.validation_message,
          identifier: identifier_result.identifier
        )
      end
    end

    private

    attr_reader :catalog_item, :identifier_type, :identifier_value, :actor

    def build_product
      product = Product.new(
        catalog_item: catalog_item,
        active: true,
        product_type: "physical",
        variation_type: "conditional",
        publication_status: catalog_item.publication_status
      )
      Products::CopyCatalogMetadata.to_product(product, catalog_item)
      product
    end
  end
end
