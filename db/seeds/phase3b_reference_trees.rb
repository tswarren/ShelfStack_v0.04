# frozen_string_literal: true

require_relative "concerns/tsv_tree_importer"

module Seeds
  module Phase3bReferenceTrees
    DISPLAY_LOCATIONS_PATH = Rails.root.join("db/seeds/data/display_locations.tsv").freeze
    STORE_CATEGORIES_PATH = Rails.root.join("db/seeds/data/store_categories.tsv").freeze

    BISAC_STORE_CATEGORY_MAP = {
      "FIC" => "fiction",
      "BIO" => "biography",
      "HIS" => "history",
      "JUV" => "childrens",
      "YAF" => "young_adult",
      "REL" => "religion",
      "CKB" => "cooking",
      "TRV" => "travel",
      "SCI" => "science",
      "ART" => "arts",
      "MUS" => "recorded_music",
      "PER" => "periodicals"
    }.freeze

    module_function

    def seed!
      import_display_locations!
      import_store_categories!
      link_bisac_store_categories!
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

    def link_bisac_store_categories!
      bisac_scheme = CategoryScheme.find_by(scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY)
      store_scheme = CategoryScheme.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      return if bisac_scheme.blank? || store_scheme.blank?

      store_nodes = store_scheme.category_nodes.index_by(&:node_key)
      linked = 0

      BISAC_STORE_CATEGORY_MAP.each do |bisac_prefix, store_node_key|
        store_node = store_nodes[store_node_key]
        next if store_node.blank?

        bisac_scheme.category_nodes.where("node_key LIKE ?", "#{bisac_prefix.downcase}%")
                      .where(default_store_category_id: nil)
                      .find_each do |node|
          node.update!(default_store_category: store_node)
          linked += 1
        end
      end

      fiction = store_nodes["fiction"]
      if fiction.present?
        bisac_scheme.category_nodes.where(default_store_category_id: nil).find_each do |node|
          node.update!(default_store_category: fiction)
          linked += 1
        end
      end

      puts "  Linked #{linked} BISAC nodes to store category suggestions"
    end
  end
end
