# frozen_string_literal: true

class CreatePhase7aInventoryReservations < ActiveRecord::Migration[8.1]
  def change
    add_column :inventory_balances, :quantity_reserved, :integer, null: false, default: 0
    add_check_constraint :inventory_balances, "quantity_reserved >= 0", name: "chk_inventory_balances_quantity_reserved"

    create_table :inventory_reservations do |t|
      t.references :store, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.references :customer_request_line, foreign_key: true
      t.references :special_order, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.string :reservation_type, null: false
      t.string :status, null: false, default: "active"
      t.integer :quantity_reserved, null: false
      t.integer :quantity_fulfilled, null: false, default: 0
      t.integer :quantity_released, null: false, default: 0
      t.references :purchase_order_line, foreign_key: true
      t.references :receipt_line, foreign_key: true
      t.references :pos_transaction_line, foreign_key: true
      t.references :reserved_by_user, null: false, foreign_key: { to_table: :users }
      t.references :override_authorized_by_user, foreign_key: { to_table: :users }
      t.datetime :reserved_at, null: false
      t.datetime :expires_at
      t.datetime :ready_at
      t.datetime :fulfilled_at
      t.datetime :released_at
      t.string :release_reason
      t.boolean :over_reserved, null: false, default: false
      t.datetime :override_authorized_at
      t.text :override_reason
      t.text :notes
      t.timestamps
    end

    add_index :inventory_reservations, %i[store_id product_variant_id status],
              name: "idx_inventory_reservations_store_variant_status"
    add_index :inventory_reservations, %i[store_id status reservation_type],
              name: "idx_inventory_reservations_store_status_type"
    add_index :inventory_reservations, :expires_at

    add_check_constraint :inventory_reservations, "quantity_reserved > 0",
                         name: "chk_inventory_reservations_quantity_reserved"
    add_check_constraint :inventory_reservations, "quantity_fulfilled >= 0",
                         name: "chk_inventory_reservations_quantity_fulfilled"
    add_check_constraint :inventory_reservations, "quantity_released >= 0",
                         name: "chk_inventory_reservations_quantity_released"
    add_check_constraint :inventory_reservations,
                         "quantity_fulfilled + quantity_released <= quantity_reserved",
                         name: "chk_inventory_reservations_quantity_balance"
  end
end
