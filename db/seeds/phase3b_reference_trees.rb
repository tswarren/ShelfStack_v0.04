# frozen_string_literal: true

require_relative "concerns/tsv_tree_importer"

module Seeds
  module Phase3bReferenceTrees
    DISPLAY_LOCATIONS_PATH = Rails.root.join("db/seeds/data/display_locations.tsv").freeze
    STORE_CATEGORIES_PATH = Rails.root.join("db/seeds/data/store_categories.tsv").freeze

    module_function

    def seed!
      import_display_locations!
      import_store_categories!
    end

    def import_display_locations!
      TsvTreeImporter.import_display_locations!(path: DISPLAY_LOCATIONS_PATH)
      TsvTreeImporter.activate_display_locations_for_all_stores!
      puts "  Seeded #{DisplayLocation.active_records.count} display locations from TSV"
    end

    def import_store_categories!
      scheme = CategoryScheme.find_or_initialize_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      scheme.assign_attributes(name: "Store Categories", purpose: CategoryNode::STORE_CATEGORIES_SCHEME_KEY, active: true)
      scheme.save!

      TsvTreeImporter.import_store_category_nodes!(
        scheme: scheme,
        path: STORE_CATEGORIES_PATH
      )
      puts "  Seeded #{scheme.category_nodes.active_records.count} store category nodes from TSV"
      scheme
    end
  end
end
