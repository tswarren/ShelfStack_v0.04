# frozen_string_literal: true

require_relative "concerns/csv_classification_importer"

module Seeds
  module Phase3bReferenceTrees
    module_function

    def seed!
      import_display_locations!
      import_store_categories!
    end

    def import_display_locations!
      CsvClassificationImporter.import_display_locations!
      CsvClassificationImporter.activate_display_locations_for_all_stores!
      puts "  Seeded #{DisplayLocation.active_records.count} display locations from CSV"
    end

    def import_store_categories!
      scheme = CategoryScheme.find_or_initialize_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      scheme.assign_attributes(name: "Store Categories", purpose: CategoryNode::STORE_CATEGORIES_SCHEME_KEY, active: true)
      scheme.save!

      CsvClassificationImporter.import_store_category_nodes!(scheme: scheme)
      puts "  Seeded #{scheme.category_nodes.active_records.count} store category nodes from CSV"
      scheme
    end
  end
end
