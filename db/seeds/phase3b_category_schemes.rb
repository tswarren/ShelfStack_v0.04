# frozen_string_literal: true

module Seeds
  module Phase3bCategorySchemes
    SCHEME = {
      scheme_key: "store_sections_topics",
      name: "Store Sections / Topics",
      purpose: "store_sections_topics"
    }.freeze

    NODES = [
      { node_key: "fiction", name: "Fiction", sort_order: 10 },
      { node_key: "biography", name: "Biography", sort_order: 20 },
      { node_key: "history", name: "History", sort_order: 30, children: [
        { node_key: "military_history", name: "Military History", sort_order: 10 },
        { node_key: "us_history", name: "U.S. History", sort_order: 20 }
      ] },
      { node_key: "religion", name: "Religion", sort_order: 40, children: [
        { node_key: "bibles", name: "Bibles", sort_order: 10 },
        { node_key: "christianity", name: "Christianity", sort_order: 20 }
      ] },
      { node_key: "stationery", name: "Stationery", sort_order: 50 },
      { node_key: "games", name: "Games", sort_order: 60 },
      { node_key: "cafe_bakery", name: "Cafe / Bakery", sort_order: 70 }
    ].freeze

    module_function

    def seed!
      scheme = CategoryScheme.find_or_initialize_by(scheme_key: SCHEME[:scheme_key])
      scheme.assign_attributes(name: SCHEME[:name], purpose: SCHEME[:purpose], active: true)
      scheme.save!

      seed_nodes!(scheme, NODES)
      scheme
    end

    def seed_nodes!(scheme, nodes, parent: nil)
      nodes.each do |node_attrs|
        attrs = node_attrs.dup
        children = attrs.delete(:children)
        node = scheme.category_nodes.find_or_initialize_by(node_key: attrs[:node_key])
        node.assign_attributes(
          name: attrs[:name],
          sort_order: attrs[:sort_order],
          parent: parent,
          active: true
        )
        node.save!
        seed_nodes!(scheme, children, parent: node) if children.present?
      end
    end
  end
end
