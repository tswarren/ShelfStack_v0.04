# frozen_string_literal: true

class AddClassificationTargetFks < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:catalog_items, :store_category_id)
      add_reference :catalog_items, :store_category, foreign_key: { to_table: :category_nodes }
    end
    unless column_exists?(:category_nodes, :default_sub_department_id)
      add_reference :category_nodes, :default_sub_department, foreign_key: { to_table: :sub_departments }
    end
    unless column_exists?(:category_nodes, :default_display_location_id)
      add_reference :category_nodes, :default_display_location, foreign_key: { to_table: :display_locations }
    end
    unless column_exists?(:category_nodes, :default_store_category_id)
      add_reference :category_nodes, :default_store_category, foreign_key: { to_table: :category_nodes }
    end
    unless column_exists?(:products, :default_sub_department_id)
      add_reference :products, :default_sub_department, foreign_key: { to_table: :sub_departments }
    end
    unless column_exists?(:product_variants, :sub_department_id)
      add_reference :product_variants, :sub_department, foreign_key: { to_table: :sub_departments }
    end
  end
end
