# frozen_string_literal: true

require_relative "concerns/tsv_tree_importer"

module Seeds
  module Phase3bCategorySchemes
    LEGACY_NODE_KEYS = %w[cafe_bakery].freeze

    module_function

    def seed!
      Seeds::Phase3bReferenceTrees.import_store_categories!
      deprecate_legacy_nodes!
    end

    def deprecate_legacy_nodes!
      scheme = CategoryScheme.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      return if scheme.blank?

      scheme.category_nodes.where(node_key: LEGACY_NODE_KEYS).find_each do |node|
        next if node.catalog_items_as_store_category.exists?

        node.update_column(:active, false)
      end
    end
  end
end
