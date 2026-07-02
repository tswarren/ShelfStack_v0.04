# frozen_string_literal: true

class AddV0049PoLineVendorQuantities < ActiveRecord::Migration[8.0]
  def change
    change_table :purchase_order_lines, bulk: true do |t|
      t.string :vendor_quantity_state, null: false, default: "unconfirmed"
      t.integer :quantity_confirmed_by_vendor, null: false, default: 0
      t.integer :quantity_backordered_by_vendor, null: false, default: 0
      t.integer :quantity_canceled_by_vendor, null: false, default: 0
      t.integer :quantity_rejected_on_line, null: false, default: 0
      t.integer :quantity_closed_short, null: false, default: 0
      t.datetime :vendor_quantities_recorded_at
      t.string :vendor_quantities_source_type
      t.bigint :vendor_quantities_source_id
    end

    add_index :purchase_order_lines, :vendor_quantity_state
  end
end
