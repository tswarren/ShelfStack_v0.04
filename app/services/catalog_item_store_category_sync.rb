# frozen_string_literal: true

class CatalogItemStoreCategorySync
  Result = Data.define(:store_category, :source, :warnings)

  def self.apply!(catalog_item:, store_category_id: nil, bisac_category_node_ids: nil)
    new(
      catalog_item: catalog_item,
      store_category_id: store_category_id,
      bisac_category_node_ids: bisac_category_node_ids
    ).apply!
  end

  def initialize(catalog_item:, store_category_id: nil, bisac_category_node_ids: nil)
    @catalog_item = catalog_item
    @store_category_id = store_category_id.presence
    @bisac_category_node_ids = Array(bisac_category_node_ids).map(&:presence).compact
    @warnings = []
  end

  def apply!
    resolved = resolve_store_category
    catalog_item.store_category = resolved.store_category
    catalog_item.save! if catalog_item.changed?

    apply_product_defaults!

    Result.new(store_category: catalog_item.store_category, source: resolved.source, warnings: warnings)
  end

  private

  attr_reader :catalog_item, :store_category_id, :bisac_category_node_ids, :warnings

  def resolve_store_category
    if store_category_id.present?
      node = CategoryNode.active_records.find(store_category_id)
      return Result.new(store_category: node, source: "manual", warnings: warnings)
    end

    Result.new(store_category: catalog_item.store_category, source: "unchanged", warnings: warnings)
  end

  def apply_product_defaults!
    defaults = StoreCategoryDefaults.for(store_category_node: catalog_item.store_category)
    return if defaults.source == "none"

    catalog_item.products.find_each do |product|
      attrs = {}
      attrs[:default_sub_department_id] = defaults.default_sub_department.id if defaults.default_sub_department.present?
      attrs[:default_display_location_id] = defaults.default_display_location.id if defaults.default_display_location.present?
      next if attrs.blank?

      product.update!(attrs)
    end
  end
end
