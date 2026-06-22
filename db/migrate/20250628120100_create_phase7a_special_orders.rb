# frozen_string_literal: true

class CreatePhase7aSpecialOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :special_orders do |t|
      t.references :store, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :customer_request_line, null: false, foreign_key: true, index: { unique: true }
      t.references :product_variant, foreign_key: true
      t.references :vendor, foreign_key: true
      t.string :status, null: false, default: "pending_match"
      t.integer :quantity_committed, null: false
      t.integer :quantity_ordered, null: false, default: 0
      t.integer :quantity_received, null: false, default: 0
      t.integer :quantity_ready, null: false, default: 0
      t.integer :quantity_completed, null: false, default: 0
      t.integer :quantity_cancelled, null: false, default: 0
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.datetime :ordered_at
      t.datetime :ready_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.text :notes
      t.timestamps
    end

    add_index :special_orders, %i[store_id status]

    add_check_constraint :special_orders, "quantity_committed > 0", name: "chk_special_orders_quantity_committed"
  end
end
