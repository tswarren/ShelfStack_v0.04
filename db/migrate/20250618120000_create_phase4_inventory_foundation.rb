# frozen_string_literal: true

class CreatePhase4InventoryFoundation < ActiveRecord::Migration[8.1]
  def change
    add_column :sub_departments, :default_margin_target_bps, :integer
    add_check_constraint :sub_departments,
                         "default_margin_target_bps IS NULL OR (default_margin_target_bps >= 0 AND default_margin_target_bps <= 10000)",
                         name: "chk_sub_departments_default_margin_target_bps"

    create_table :inventory_reason_codes do |t|
      t.string :reason_key, null: false, limit: 40
      t.string :name, null: false
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :inventory_reason_codes, :reason_key, unique: true
    add_index :inventory_reason_codes, :name, unique: true
    add_index :inventory_reason_codes, :active

    create_table :inventory_locations do |t|
      t.references :store, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :short_name, null: false, limit: 40
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :inventory_locations, %i[store_id short_name], unique: true
    add_index :inventory_locations, :active

    create_table :inventory_postings do |t|
      t.string :posting_type, null: false
      t.string :source_type, null: false
      t.bigint :source_id, null: false
      t.references :store, null: false, foreign_key: true, index: true
      t.datetime :posted_at, null: false
      t.references :posted_by_user, null: false, foreign_key: { to_table: :users }
      t.references :workstation, foreign_key: true, index: true
      t.string :idempotency_key, null: false
      t.references :reversal_of_posting, foreign_key: { to_table: :inventory_postings }, index: true
      t.references :reversed_by_posting, foreign_key: { to_table: :inventory_postings }, index: true
      t.text :notes
      t.timestamps
    end
    add_index :inventory_postings, %i[source_type source_id], unique: true
    add_index :inventory_postings, :idempotency_key, unique: true
    add_index :inventory_postings, %i[store_id posted_at]
    add_index :inventory_postings, :posting_type

    create_table :inventory_adjustments do |t|
      t.references :store, null: false, foreign_key: true, index: true
      t.string :adjustment_type, null: false
      t.string :status, null: false, default: "draft"
      t.text :notes
      t.datetime :posted_at
      t.references :posted_by_user, foreign_key: { to_table: :users }, index: true
      t.references :inventory_posting, foreign_key: true, index: true
      t.timestamps
    end
    add_index :inventory_adjustments, %i[store_id status]
    add_index :inventory_adjustments, :adjustment_type

    create_table :inventory_adjustment_lines do |t|
      t.references :inventory_adjustment, null: false, foreign_key: true, index: true
      t.integer :line_number, null: false
      t.references :product_variant, null: false, foreign_key: true, index: true
      t.integer :quantity_delta, null: false
      t.integer :unit_cost_cents
      t.references :inventory_location, foreign_key: true, index: true
      t.references :inventory_reason_code, foreign_key: true, index: true
      t.timestamps
    end
    add_index :inventory_adjustment_lines, %i[inventory_adjustment_id line_number],
              unique: true, name: "idx_inventory_adjustment_lines_adjustment_line_number"

    create_table :inventory_ledger_entries do |t|
      t.references :inventory_posting, null: false, foreign_key: true, index: true
      t.integer :line_number, null: false
      t.references :product_variant, null: false, foreign_key: true, index: true
      t.references :store, null: false, foreign_key: true, index: true
      t.references :inventory_location, foreign_key: true, index: true
      t.string :movement_type, null: false
      t.integer :quantity_delta, null: false
      t.integer :unit_cost_cents
      t.integer :total_cost_cents
      t.integer :unit_retail_cents
      t.integer :total_retail_cents
      t.string :cost_source, null: false
      t.string :retail_source, null: false
      t.references :inventory_reason_code, foreign_key: true, index: true
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :inventory_ledger_entries, %i[inventory_posting_id line_number],
              unique: true, name: "idx_inventory_ledger_entries_posting_line_number"
    add_index :inventory_ledger_entries, %i[store_id product_variant_id],
              name: "idx_inventory_ledger_entries_store_variant"
    add_index :inventory_ledger_entries, %i[product_variant_id occurred_at],
              name: "idx_inventory_ledger_entries_variant_occurred_at"

    create_table :inventory_balances do |t|
      t.references :store, null: false, foreign_key: true, index: true
      t.references :product_variant, null: false, foreign_key: true, index: true
      t.integer :quantity_on_hand, null: false, default: 0
      t.integer :quantity_available, null: false, default: 0
      t.integer :inventory_cost_value_cents, null: false, default: 0
      t.integer :inventory_retail_value_cents, null: false, default: 0
      t.integer :unit_cost_cents
      t.integer :unit_retail_cents
      t.string :cost_source
      t.string :retail_source
      t.references :last_posting, foreign_key: { to_table: :inventory_postings }, index: true
      t.timestamps
    end
    add_index :inventory_balances, %i[store_id product_variant_id], unique: true
    add_index :inventory_balances, %i[store_id quantity_on_hand],
              name: "idx_inventory_balances_store_quantity_on_hand"
  end
end
