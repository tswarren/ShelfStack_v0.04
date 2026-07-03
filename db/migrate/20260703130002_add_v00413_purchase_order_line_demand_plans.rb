# frozen_string_literal: true

class AddV00413PurchaseOrderLineDemandPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :purchase_order_line_demand_plans do |t|
      t.references :store, null: false, foreign_key: true
      t.references :purchase_order, null: false, foreign_key: true
      t.references :purchase_order_line, null: false, foreign_key: true
      t.references :demand_line, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.integer :quantity_planned, null: false
      t.string :fulfillment_route, null: false, default: "inbound_to_store"
      t.string :coverage_kind, null: false, default: "other"
      t.string :status, null: false, default: "planned"
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.references :converted_to_demand_allocation, foreign_key: { to_table: :demand_allocations }
      t.datetime :converted_at
      t.references :converted_by_user, foreign_key: { to_table: :users }
      t.datetime :released_at
      t.references :released_by_user, foreign_key: { to_table: :users }
      t.text :release_reason
      t.string :idempotency_key
      t.text :notes
      t.timestamps
    end

    add_index :purchase_order_line_demand_plans,
              %i[purchase_order_line_id demand_line_id status],
              name: "idx_po_line_demand_plans_line_demand_status"
    add_index :purchase_order_line_demand_plans, %i[demand_line_id status]
    add_index :purchase_order_line_demand_plans, %i[store_id purchase_order_id]
    add_index :purchase_order_line_demand_plans,
              %i[store_id idempotency_key],
              unique: true,
              where: "idempotency_key IS NOT NULL",
              name: "idx_po_line_demand_plans_store_idempotency"
  end
end
