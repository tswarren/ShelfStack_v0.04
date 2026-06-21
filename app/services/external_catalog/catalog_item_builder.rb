# frozen_string_literal: true

module ExternalCatalog
  class CatalogItemBuilder
    def self.create!(candidate:, format:, actor:)
      new(candidate:, format:, actor:).create!
    end

    def self.add_identifiers!(catalog_item:, candidate:, actor:)
      new(candidate: candidate, format: catalog_item.format, actor: actor).add_identifiers!(catalog_item)
    end

    def initialize(candidate:, format:, actor:)
      @candidate = candidate
      @format = format
      @actor = actor
    end

    def create!
      attrs = MetadataMapper.catalog_attributes(candidate: @candidate).merge(
        format: @format,
        publication_status: "active",
        active: true
      )

      catalog_item = nil
      CatalogItem.transaction do
        catalog_item = CatalogItem.create!(attrs)
        add_identifiers!(catalog_item)
      end

      AuditEvents.record!(
        actor: @actor,
        event_name: "catalog_item.created",
        auditable: catalog_item,
        details: { "source" => "external_catalog_import" }
      )

      catalog_item.reload
    end

    def add_identifiers!(catalog_item)
      if @candidate.isbn13.present?
        CatalogIdentifierService.add_identifier!(
          catalog_item: catalog_item,
          identifier_type: "isbn13",
          value: @candidate.isbn13,
          primary: true,
          actor: @actor,
          source: "isbndb"
        )
      end

      if @candidate.isbn10.present?
        CatalogIdentifierService.add_identifier!(
          catalog_item: catalog_item,
          identifier_type: "isbn10",
          value: @candidate.isbn10,
          primary: @candidate.isbn13.blank?,
          actor: @actor,
          source: "isbndb"
        )
      end

      if catalog_item.primary_identifier.blank?
        CatalogIdentifierService.generate_local!(catalog_item: catalog_item, actor: @actor)
      end
    end
  end
end
