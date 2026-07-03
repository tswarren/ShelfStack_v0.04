# frozen_string_literal: true

class AddV00413PurchaseOrderDestination < ActiveRecord::Migration[8.0]
  def change
    change_table :purchase_orders, bulk: true do |t|
      t.string :order_purpose, null: false, default: "stock_order"
      t.string :ship_to_type, null: false, default: "store"
      t.jsonb :ship_to_snapshot
    end
  end
end
