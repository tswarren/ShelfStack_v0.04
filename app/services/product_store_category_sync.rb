# frozen_string_literal: true

class ProductStoreCategorySync
  Result = Data.define(:store_category, :source, :warnings)

  def self.apply!(product:, store_category_id: nil, bisac_category_node_ids: nil)
    new(
      product: product,
      store_category_id: store_category_id,
      bisac_category_node_ids: bisac_category_node_ids
    ).apply!
  end

  def initialize(product:, store_category_id: nil, bisac_category_node_ids: nil)
    @product = product
    @store_category_id = store_category_id.presence
    @bisac_category_node_ids = Array(bisac_category_node_ids).map(&:presence).compact
    @warnings = []
  end

  def apply!
    resolved = resolve_store_category
    product.store_category = resolved.store_category
    product.save! if product.changed?

    apply_product_defaults!

    Result.new(store_category: product.store_category, source: resolved.source, warnings: warnings)
  end

  private

  attr_reader :product, :store_category_id, :bisac_category_node_ids, :warnings

  def resolve_store_category
    if store_category_id.present?
      node = CategoryNode.active_records.find(store_category_id)
      return Result.new(store_category: node, source: "manual", warnings: warnings)
    end

    Result.new(store_category: product.store_category, source: "unchanged", warnings: warnings)
  end

  def apply_product_defaults!
    defaults = StoreCategoryDefaults.for(store_category_node: product.store_category)
    return if defaults.source == "none"

    attrs = {}
    attrs[:default_sub_department_id] = defaults.default_sub_department.id if defaults.default_sub_department.present?
    attrs[:default_display_location_id] = defaults.default_display_location.id if defaults.default_display_location.present?
    return if attrs.blank?

    product.update!(attrs)
  end
end
