# frozen_string_literal: true

class CreatePhase7aPoLineAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_order_line_allocations do |t|
      t.references :purchase_order_line, null: false, foreign_key: true
      t.references :special_order, null: false, foreign_key: true
      t.references :customer_request_line, foreign_key: true
      t.integer :quantity_allocated, null: false
      t.integer :quantity_received, null: false, default: 0
      t.string :status, null: false, default: "active"
      t.timestamps
    end

    add_check_constraint :purchase_order_line_allocations, "quantity_allocated > 0",
                         name: "chk_po_line_allocations_quantity_allocated"
    add_check_constraint :purchase_order_line_allocations, "quantity_received >= 0",
                         name: "chk_po_line_allocations_quantity_received"
  end
end
