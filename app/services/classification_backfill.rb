# frozen_string_literal: true

class ClassificationBackfill
  STORE_SCHEME_KEYS = [
    CategoryNode::STORE_CATEGORIES_SCHEME_KEY,
    CategoryNode::LEGACY_STORE_SCHEME_KEY
  ].freeze

  def self.call
    new.call
  end

  def call
    rename_store_scheme!
    backfill_sub_department_departments!
    backfill_catalog_store_categories!
    backfill_product_defaults!
    backfill_bisac_store_category_suggestions!
    stats
  end

  private

  def stats
    @stats ||= Hash.new(0)
  end

  def rename_store_scheme!
    scheme = CategoryScheme.find_by(scheme_key: CategoryNode::LEGACY_STORE_SCHEME_KEY)
    return if scheme.blank?

    scheme.update!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY, purpose: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
    stats[:store_scheme_renamed] += 1
  end

  def backfill_sub_department_departments!
    SubDepartment.where(department_id: nil).find_each do |sub_department|
      department_id = Category.where(sub_department_id: sub_department.id).pick(:department_id)
      next if department_id.blank?

      sub_department.update_columns(department_id: department_id)
      stats[:sub_department_departments] += 1
    end
  end

  def backfill_catalog_store_categories!
    store_scheme_ids = CategoryScheme.where(scheme_key: STORE_SCHEME_KEYS).pluck(:id)

    ProductVariant.includes(product: :catalog_item).find_each do |variant|
      catalog_item = variant.product&.catalog_item
      next if catalog_item.blank? || catalog_item.store_category_id.present?

      categorization = variant.categorizations.primary_records.joins(:category_node)
                               .where(category_nodes: { category_scheme_id: store_scheme_ids })
                               .first
      next if categorization.blank?

      catalog_item.update_columns(store_category_id: categorization.category_node_id)
      stats[:catalog_store_categories] += 1
    end
  end

  def backfill_product_defaults!
    Product.includes(catalog_item: :store_category).where(default_sub_department_id: nil).find_each do |product|
      store_category = product.catalog_item&.store_category
      next if store_category.blank?

      attrs = {}
      attrs[:default_sub_department_id] = store_category.default_sub_department_id if store_category.default_sub_department_id.present?
      attrs[:default_display_location_id] = store_category.default_display_location_id if store_category.default_display_location_id.present?
      next if attrs.blank?

      product.update_columns(attrs)
      stats[:product_defaults] += 1
    end
  end

  def backfill_bisac_store_category_suggestions!
    fiction = store_category_node("fiction")
    return if fiction.blank?

    bisac_scheme = CategoryScheme.find_by(scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY)
    return if bisac_scheme.blank?

    bisac_scheme.category_nodes.where(default_store_category_id: nil).find_each do |node|
      node.update_columns(default_store_category_id: fiction.id)
      stats[:bisac_store_category_links] += 1
    end
  end

  def store_category_node(node_key)
    CategoryScheme.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
                  &.category_nodes&.find_by(node_key: node_key)
  end
end
