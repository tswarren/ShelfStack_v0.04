# frozen_string_literal: true

class CreateV0048SourcingRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :sourcing_runs do |t|
      t.references :store, null: false, foreign_key: true
      t.references :demand_line, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.integer :quantity_requested, null: false
      t.references :started_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :started_at, null: false
      t.references :closed_by_user, foreign_key: { to_table: :users }
      t.datetime :closed_at
      t.text :close_reason
      t.references :canceled_by_user, foreign_key: { to_table: :users }
      t.datetime :canceled_at
      t.text :cancel_reason
      t.text :notes
      t.timestamps
    end

    add_index :sourcing_runs, %i[demand_line_id status]
    add_index :sourcing_runs, %i[store_id status started_at]
    add_index :sourcing_runs, %i[store_id product_variant_id status]
    add_index :sourcing_runs, :demand_line_id,
              unique: true,
              where: "status IN ('open', 'partially_resolved', 'needs_review')",
              name: "index_sourcing_runs_one_active_per_demand_line"
    add_check_constraint :sourcing_runs, "quantity_requested > 0", name: "sourcing_runs_quantity_positive"
  end
end
