# frozen_string_literal: true

class AddV0049DemandAllocationConversionFields < ActiveRecord::Migration[8.0]
  def change
    change_table :demand_allocations, bulk: true do |t|
      t.bigint :converted_from_allocation_id
      t.bigint :converted_to_allocation_id
      t.bigint :conversion_receipt_line_id
      t.bigint :conversion_purchase_order_line_id
      t.datetime :converted_at
      t.bigint :converted_by_user_id
      t.string :conversion_reason
    end

    add_foreign_key :demand_allocations, :demand_allocations, column: :converted_from_allocation_id
    add_foreign_key :demand_allocations, :demand_allocations, column: :converted_to_allocation_id
    add_foreign_key :demand_allocations, :receipt_lines, column: :conversion_receipt_line_id
    add_foreign_key :demand_allocations, :purchase_order_lines, column: :conversion_purchase_order_line_id
    add_foreign_key :demand_allocations, :users, column: :converted_by_user_id

    add_index :demand_allocations, :conversion_receipt_line_id
    add_index :demand_allocations, :conversion_purchase_order_line_id
    add_index :demand_allocations, :converted_from_allocation_id
  end
end
