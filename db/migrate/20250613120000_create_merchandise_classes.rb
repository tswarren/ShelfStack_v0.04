# frozen_string_literal: true

class CreateMerchandiseClasses < ActiveRecord::Migration[8.0]
  def change
    create_table :merchandise_classes do |t|
      t.string :merchandise_class_key, null: false
      t.string :name, null: false
      t.string :short_name, null: false
      t.string :default_pricing_model
      t.references :default_tax_category, null: false, foreign_key: { to_table: :tax_categories }
      t.integer :default_margin_target_bps
      t.integer :default_supplier_discount_bps
      t.boolean :has_list_price, null: false, default: true
      t.boolean :vendor_discounts_from_list_price, null: false, default: true
      t.boolean :store_marks_up_from_cost, null: false, default: false
      t.boolean :vendor_returnable_default, null: false, default: false
      t.boolean :used_sales_allowed, null: false, default: false
      t.boolean :buyback_allowed, null: false, default: false
      t.string :default_sales_account_code, limit: 20
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :merchandise_classes, :merchandise_class_key, unique: true
    add_index :merchandise_classes, :name, unique: true
    add_index :merchandise_classes, :short_name, unique: true
  end
end
