# frozen_string_literal: true

class CreatePhase2ClassificationAndTax < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_categories do |t|
      t.string :name, null: false
      t.string :short_name, null: false, limit: 20
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :tax_categories, :name, unique: true
    add_index :tax_categories, :short_name, unique: true
    add_index :tax_categories, :sort_order
    add_index :tax_categories, :active

    create_table :store_tax_rates do |t|
      t.references :store, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :short_name, null: false, limit: 20
      t.string :tax_identifier, null: false, limit: 1
      t.integer :tax_rate_bps, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :store_tax_rates, [ :store_id, :name ], unique: true
    add_index :store_tax_rates, [ :store_id, :short_name ], unique: true
    add_index :store_tax_rates, [ :store_id, :tax_identifier ], unique: true
    add_index :store_tax_rates, :active

    create_table :store_tax_category_rates do |t|
      t.references :store, null: false, foreign_key: true, index: true
      t.references :tax_category, null: false, foreign_key: true, index: true
      t.references :store_tax_rate, null: false, foreign_key: true, index: true
      t.date :effective_on, null: false
      t.date :ends_on
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :store_tax_category_rates, [ :store_id, :tax_category_id, :effective_on ], unique: true,
              name: "idx_store_tax_cat_rates_store_tax_cat_effective"
    add_index :store_tax_category_rates, [ :store_id, :tax_category_id, :active ],
              name: "idx_store_tax_cat_rates_store_tax_cat_active"
    add_index :store_tax_category_rates, [ :effective_on, :ends_on ]

    create_table :departments do |t|
      t.string :department_number, null: false, limit: 3
      t.string :name, null: false
      t.string :short_name, null: false, limit: 20
      t.string :gl_account_code, limit: 20
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :departments, :department_number, unique: true
    add_index :departments, :name, unique: true
    add_index :departments, :short_name, unique: true
    add_index :departments, :gl_account_code
    add_index :departments, :active

    create_table :categories do |t|
      t.references :department, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :short_name, null: false, limit: 20
      t.integer :sort_order, null: false, default: 0
      t.string :default_pricing_model
      t.integer :default_margin_target_bps
      t.integer :default_supplier_discount_bps
      t.references :default_tax_category, null: false, foreign_key: { to_table: :tax_categories }, index: true
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :categories, [ :department_id, :name ], unique: true
    add_index :categories, [ :department_id, :short_name ], unique: true
    add_index :categories, [ :department_id, :sort_order ]
    add_index :categories, :default_pricing_model
    add_index :categories, :active
  end
end
