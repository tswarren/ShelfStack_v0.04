# frozen_string_literal: true

module Products
  class CopyCatalogMetadata
    def self.to_product(product, catalog_item)
      new(product, catalog_item).call
    end

    def initialize(product, catalog_item)
      @product = product
      @catalog_item = catalog_item
    end

    def call
      @product.assign_attributes(
        catalog_item_type: @catalog_item.catalog_item_type,
        title: @catalog_item.title,
        creators: @catalog_item.creators,
        creator_details: @catalog_item.creator_details,
        publisher: @catalog_item.publisher,
        publisher_details: @catalog_item.publisher_details,
        publication_date: @catalog_item.publication_date,
        publication_status: @catalog_item.publication_status,
        series_name: @catalog_item.series_name,
        series_enumeration: @catalog_item.series_enumeration,
        series_data: @catalog_item.series_data,
        format_id: @catalog_item.format_id,
        edition_statement: @catalog_item.edition_statement,
        language_code: @catalog_item.language_code,
        description: @catalog_item.description,
        year: @catalog_item.year,
        bisac_subjects: @catalog_item.bisac_subjects,
        bisac_subject_data: @catalog_item.bisac_subject_data,
        genres: @catalog_item.genres,
        genre_data: @catalog_item.genre_data,
        themes: @catalog_item.themes,
        theme_data: @catalog_item.theme_data,
        target_audiences: @catalog_item.target_audiences,
        target_audience_data: @catalog_item.target_audience_data,
        access_restrictions: @catalog_item.access_restrictions,
        access_restriction_data: @catalog_item.access_restriction_data,
        publication_frequency: @catalog_item.publication_frequency,
        digital: @catalog_item.digital,
        large_print: @catalog_item.large_print,
        page_count: @catalog_item.page_count,
        duration_minutes: @catalog_item.duration_minutes,
        height: @catalog_item.height,
        width: @catalog_item.width,
        depth: @catalog_item.depth,
        dimension_units: @catalog_item.dimension_units,
        weight: @catalog_item.weight,
        weight_units: @catalog_item.weight_units,
        store_category_id: @catalog_item.store_category_id,
        source: @catalog_item.source,
        needs_review: @catalog_item.needs_review
      )
      @product
    end
  end
end
