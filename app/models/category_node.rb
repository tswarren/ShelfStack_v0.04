# frozen_string_literal: true

class CategoryNode < ApplicationRecord
  STORE_CATEGORIES_SCHEME_KEY = "store_categories"
  LEGACY_STORE_SCHEME_KEY = "store_sections_topics"

  belongs_to :category_scheme
  belongs_to :parent, class_name: "CategoryNode", optional: true
  belongs_to :default_sub_department, class_name: "SubDepartment", optional: true
  belongs_to :default_display_location, class_name: "DisplayLocation", optional: true
  belongs_to :default_store_category, class_name: "CategoryNode", optional: true

  has_many :children, class_name: "CategoryNode", foreign_key: :parent_id, dependent: :restrict_with_error,
           inverse_of: :parent
  has_many :categorizations, dependent: :restrict_with_error
  has_many :accounting_mappings, dependent: :restrict_with_error
  has_many :catalog_items_as_store_category, class_name: "CatalogItem", foreign_key: :store_category_id,
           dependent: :restrict_with_error, inverse_of: :store_category

  validates :node_key, presence: true, uniqueness: { scope: :category_scheme_id }, length: { maximum: 30 }
  validates :name, presence: true, uniqueness: { scope: %i[category_scheme_id parent_id] }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parent_must_belong_to_same_scheme
  validate :parent_must_be_active
  validate :default_sub_department_must_be_active
  validate :default_display_location_must_be_active
  validate :default_store_category_must_be_store_category_node

  scope :active_records, -> { where(active: true) }

  def self.ordered_tree_rows_for(category_scheme)
    TreeOrdering.rows(
      category_scheme.category_nodes
        .includes(:default_sub_department, :default_display_location)
        .order(:sort_order, :node_key, :name)
        .to_a
    )
  end

  def self.active_for_tree_select(category_scheme)
    category_scheme.category_nodes.active_records.order(:sort_order, :node_key, :name).to_a
  end

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def breadcrumb_label
    return name if parent.blank?

    "#{parent.breadcrumb_label} → #{name}"
  end

  def store_category?
    category_scheme&.scheme_key.in?([ STORE_CATEGORIES_SCHEME_KEY, LEGACY_STORE_SCHEME_KEY ])
  end

  private

  def normalize_strings
    self.node_key = node_key&.strip&.downcase
    self.name = name&.strip
  end

  def parent_must_belong_to_same_scheme
    return if parent.blank? || parent.category_scheme_id == category_scheme_id

    errors.add(:parent, "must belong to the same scheme")
  end

  def parent_must_be_active
    return if parent.blank? || parent.active?

    errors.add(:parent, "must be active")
  end

  def default_sub_department_must_be_active
    return if default_sub_department.blank? || default_sub_department.active?

    errors.add(:default_sub_department, "must be active")
  end

  def default_display_location_must_be_active
    return if default_display_location.blank? || default_display_location.active?

    errors.add(:default_display_location, "must be active")
  end

  def default_store_category_must_be_store_category_node
    return if default_store_category.blank?

    unless default_store_category.store_category?
      errors.add(:default_store_category, "must belong to the store categories scheme")
    end
  end
end
