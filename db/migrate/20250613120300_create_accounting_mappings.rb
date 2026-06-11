# frozen_string_literal: true

class CreateAccountingMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :accounting_mappings do |t|
      t.references :merchandise_class, foreign_key: true
      t.references :condition, foreign_key: { to_table: :product_conditions }
      t.references :category_node, foreign_key: true
      t.string :product_type
      t.string :sales_account_code, null: false, limit: 20
      t.string :reporting_bucket, limit: 50
      t.string :gl_export_code, limit: 20
      t.string :description
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :accounting_mappings, :sales_account_code
    add_index :accounting_mappings, :product_type
  end
end
