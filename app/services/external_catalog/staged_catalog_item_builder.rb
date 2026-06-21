# frozen_string_literal: true

module ExternalCatalog
  class StagedCatalogItemBuilder
    def self.build(lookup_result:, format: nil)
      new(lookup_result:, format:).build
    end

    def initialize(lookup_result:, format: nil)
      @lookup_result = lookup_result
      @format = format
    end

    def build
      resolved_format = @format || CatalogImport::BindingFormatMapper.resolve(@lookup_result.binding_snapshot)
      raise ArgumentError, "Format is required to stage catalog item details." if resolved_format.blank?

      attrs = MetadataMapper.catalog_attributes(candidate: @lookup_result).merge(
        format: resolved_format,
        publication_status: "active",
        active: true,
        catalog_item_type: "book"
      )

      CatalogItem.new(attrs)
    end
  end
end
