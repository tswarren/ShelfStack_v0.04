# frozen_string_literal: true

class CreateV0047DemandAllocations < ActiveRecord::Migration[8.0]
  def change
    create_table :demand_allocations do |t|
      t.references :store, null: false, foreign_key: true
      t.references :demand_line, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.string :allocation_kind, null: false
      t.string :status, null: false, default: "active"
      t.integer :quantity_allocated, null: false
      t.references :purchase_order_line, foreign_key: true
      t.datetime :expires_at
      t.references :allocated_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :allocated_at, null: false
      t.references :released_by_user, foreign_key: { to_table: :users }
      t.datetime :released_at
      t.text :release_reason
      t.references :canceled_by_user, foreign_key: { to_table: :users }
      t.datetime :canceled_at
      t.text :cancel_reason
      t.references :expired_by_user, foreign_key: { to_table: :users }
      t.datetime :expired_at
      t.references :fulfilled_by_user, foreign_key: { to_table: :users }
      t.datetime :fulfilled_at
      t.string :fulfillment_reference_type
      t.bigint :fulfillment_reference_id
      t.boolean :override_availability, null: false, default: false
      t.references :override_authorized_by_user, foreign_key: { to_table: :users }
      t.datetime :override_authorized_at
      t.text :override_reason
      t.text :notes
      t.timestamps
    end

    add_index :demand_allocations, %i[demand_line_id status]
    add_index :demand_allocations, %i[store_id product_variant_id allocation_kind status],
              name: "index_demand_allocations_on_store_variant_kind_status"
    add_index :demand_allocations, %i[purchase_order_line_id status]
    add_index :demand_allocations, %i[status expires_at]
    add_index :demand_allocations, %i[store_id status expires_at]
    add_check_constraint :demand_allocations, "quantity_allocated > 0", name: "demand_allocations_quantity_positive"
  end
end
