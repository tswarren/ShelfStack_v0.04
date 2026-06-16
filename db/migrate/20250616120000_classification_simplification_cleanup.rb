# frozen_string_literal: true

class ClassificationSimplificationCleanup < ActiveRecord::Migration[8.0]
  SUB_DEPARTMENT_COLUMNS = %w[
    default_margin_target_bps
    default_supplier_discount_bps
    has_list_price
    vendor_discounts_from_list_price
    store_marks_up_from_cost
    used_sales_allowed
    default_sales_account_code
    default_variation_type
    default_inventory_behavior
  ].freeze

  def up
    drop_table :accounting_mappings, if_exists: true
    drop_table :categories, if_exists: true

    SUB_DEPARTMENT_COLUMNS.each do |column|
      remove_column :sub_departments, column, if_exists: true
    end

    if column_exists?(:category_nodes, :default_store_category_id)
      remove_reference :category_nodes, :default_store_category, foreign_key: { to_table: :category_nodes }
    end

    flatten_bisac_nodes!
  end

  def down
    add_reference :category_nodes, :default_store_category, foreign_key: { to_table: :category_nodes }, index: true

    add_index :category_nodes, %i[category_scheme_id name],
              name: "index_category_nodes_on_scheme_and_root_name",
              unique: true,
              where: "parent_id IS NULL",
              if_not_exists: true

    change_table :sub_departments, bulk: true do |t|
      t.integer :default_margin_target_bps
      t.integer :default_supplier_discount_bps
      t.boolean :has_list_price, null: false, default: true
      t.boolean :vendor_discounts_from_list_price, null: false, default: true
      t.boolean :store_marks_up_from_cost, null: false, default: false
      t.boolean :used_sales_allowed, null: false, default: false
      t.string :default_sales_account_code, limit: 20
      t.string :default_variation_type, null: false, default: "standard"
      t.string :default_inventory_behavior, null: false, default: "standard_physical"
    end

    create_table :categories do |t|
      t.references :department, null: false, foreign_key: true
      t.references :sub_department, foreign_key: true
      t.references :default_tax_category, null: false, foreign_key: { to_table: :tax_categories }
      t.string :name, null: false
      t.string :short_name, limit: 20, null: false
      t.integer :sort_order, null: false, default: 0
      t.string :default_pricing_model
      t.integer :default_margin_target_bps
      t.integer :default_supplier_discount_bps
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :categories, %i[department_id name], unique: true
    add_index :categories, %i[department_id short_name], unique: true
    add_index :categories, %i[department_id sort_order]
    add_index :categories, :default_pricing_model
    add_index :categories, :active

    create_table :accounting_mappings do |t|
      t.references :sub_department, foreign_key: true
      t.references :condition, foreign_key: { to_table: :product_conditions }
      t.references :category_node, foreign_key: true
      t.string :product_type
      t.string :sales_account_code, null: false
      t.string :reporting_bucket, limit: 50
      t.string :gl_export_code, limit: 20
      t.text :description
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :accounting_mappings, :sales_account_code
    add_index :accounting_mappings, :product_type
  end

  private

  def flatten_bisac_nodes!
    return unless table_exists?(:category_schemes) && table_exists?(:category_nodes)

    remove_index :category_nodes, name: "index_category_nodes_on_scheme_and_root_name", if_exists: true

    execute <<~SQL.squish
      UPDATE category_nodes
      SET parent_id = NULL
      WHERE category_scheme_id IN (SELECT id FROM category_schemes WHERE scheme_key = 'bisac')
        AND parent_id IS NOT NULL
    SQL
  end
end
