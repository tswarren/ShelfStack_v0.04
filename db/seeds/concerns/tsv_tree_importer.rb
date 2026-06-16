# frozen_string_literal: true

require_relative "csv_classification_importer"

module Seeds
  # Deprecated: delegate to CsvClassificationImporter (CSV replaces TSV seed files).
  module TsvTreeImporter
    module_function

    def parse_tsv(path)
      raise ArgumentError, "TsvTreeImporter is deprecated; use CsvClassificationImporter with CSV files"
    end

    def import_display_locations!(path:)
      CsvClassificationImporter.import_display_locations!(path: path)
    end

    def activate_display_locations_for_all_stores!
      CsvClassificationImporter.activate_display_locations_for_all_stores!
    end

    def sub_department_index
      CsvClassificationImporter.sub_department_index
    end

    def display_location_index
      CsvClassificationImporter.display_location_index
    end

    def import_store_category_nodes!(scheme:, path:, sub_department_index: sub_department_index(),
                                     display_location_index: display_location_index())
      CsvClassificationImporter.import_store_category_nodes!(
        scheme: scheme,
        path: path,
        sub_department_index: sub_department_index,
        display_location_index: display_location_index
      )
    end
  end
end
