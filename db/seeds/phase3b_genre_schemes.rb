# frozen_string_literal: true

require_relative "concerns/csv_classification_importer"

module Seeds
  module Phase3bGenreSchemes
    module_function

    def seed!
      CsvClassificationImporter.import_formats_mvp!
      puts "  Seeded #{Format.where.not(catalog_item_type: nil).count} MVP formats from CSV"

      CsvClassificationImporter.import_all_genre_schemes!
      CategoryScheme.where(purpose: CategoryScheme::GENRE_PURPOSES).find_each do |scheme|
        puts "  Seeded #{scheme.category_nodes.active_records.count} #{scheme.scheme_key} nodes from CSV"
      end
    end
  end
end
