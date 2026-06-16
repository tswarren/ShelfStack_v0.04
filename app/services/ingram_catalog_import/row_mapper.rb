# frozen_string_literal: true

module IngramCatalogImport
  class RowMapper
    def self.catalog_attributes(row:, format:)
      {
        catalog_item_type: ProductTypeMapper.resolve!(row.product_type),
        title: row.product_name,
        creators: row.contributor,
        publisher: row.supplier,
        series_name: row.series,
        bisac_subjects: row.bisac_category,
        publication_date: row.pub_date,
        weight: row.weight,
        weight_units: row.weight.present? ? "lb" : nil,
        format: format,
        active: true,
        publication_status: "active"
      }
    end
  end
end
