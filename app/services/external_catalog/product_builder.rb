# frozen_string_literal: true

module ExternalCatalog
  class ProductBuilder
    def self.create!(candidate:, format:, actor:)
      new(candidate:, format:, actor:).create!
    end

    def self.assign_transitional_sku!(product:, candidate:, actor:)
      new(candidate: candidate, format: product.format, actor: actor).assign_transitional_sku!(product)
    end

    def initialize(candidate:, format:, actor:)
      @candidate = candidate
      @format = format
      @actor = actor
    end

    def create!
      attrs = MetadataMapper.product_attributes(candidate: @candidate).merge(
        format: @format,
        publication_status: "active",
        active: true,
        product_type: "physical",
        variation_type: "conditional"
      )

      product = nil
      Product.transaction do
        product = Product.new(attrs)
        assign_transitional_sku!(product)
        product.save!
        create_product_identifiers!(product)
      end

      AuditEvents.record!(
        actor: @actor,
        event_name: "product.created",
        auditable: product,
        details: { "source" => "external_catalog_import" }
      )

      product.reload
    end

    def assign_transitional_sku!(product)
      AddItem::TransitionalSkuAssigner.assign!(
        product: product,
        candidate: @candidate,
        actor: @actor
      )
    end

    private

    def create_product_identifiers!(product)
      if @candidate.isbn10.present?
        ProductIdentifierService.add_identifier!(
          product: product,
          validation_family: "isbn",
          value: @candidate.isbn10,
          primary: true,
          actor: @actor,
          source: "external_catalog_import"
        )
      elsif @candidate.isbn13.present?
        ProductIdentifierService.add_identifier!(
          product: product,
          validation_family: "gtin",
          value: @candidate.isbn13,
          primary: true,
          actor: @actor,
          source: "external_catalog_import"
        )
      elsif product.sku.present?
        ProductIdentifierService.add_identifier!(
          product: product,
          validation_family: "freeform",
          value: product.sku,
          freeform_scope: ProductIdentifierService.infer_freeform_scope(product.sku),
          primary: true,
          actor: @actor,
          source: "external_catalog_import"
        )
      end
    rescue ProductIdentifierService::IdentifierError
      nil
    end
  end
end
