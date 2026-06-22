# frozen_string_literal: true

class CreatePhase7aReceiptLineAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :receipt_line_allocations do |t|
      t.references :receipt_line, null: false, foreign_key: true
      t.references :purchase_order_line_allocation, foreign_key: true
      t.references :inventory_reservation, foreign_key: true
      t.references :customer_request_line, foreign_key: true
      t.references :special_order, foreign_key: true
      t.integer :quantity_allocated, null: false
      t.timestamps
    end

    add_check_constraint :receipt_line_allocations, "quantity_allocated > 0",
                         name: "chk_receipt_line_allocations_quantity_allocated"
  end
end
