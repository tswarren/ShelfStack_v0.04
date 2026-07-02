# frozen_string_literal: true

class CreateV0048SourcingAttempts < ActiveRecord::Migration[8.0]
  def change
    create_table :sourcing_attempts do |t|
      t.references :store, null: false, foreign_key: true
      t.references :sourcing_run, null: false, foreign_key: true
      t.references :demand_line, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: true
      t.references :product_variant_vendor, foreign_key: true
      t.references :product_vendor, foreign_key: true
      t.references :purchase_order_line, foreign_key: true
      t.references :previous_sourcing_attempt, foreign_key: { to_table: :sourcing_attempts }
      t.string :status, null: false, default: "pending"
      t.integer :sequence_number, null: false
      t.integer :quantity_requested, null: false
      t.references :submitted_by_user, foreign_key: { to_table: :users }
      t.datetime :submitted_at
      t.datetime :response_due_at
      t.string :cascade_reason
      t.boolean :buyer_review_required, null: false, default: false
      t.boolean :manual_vendor_override, null: false, default: false
      t.text :manual_override_reason
      t.references :override_authorized_by_user, foreign_key: { to_table: :users }
      t.datetime :override_authorized_at
      t.string :vendor_name_snapshot
      t.string :vendor_item_number_snapshot
      t.string :source_level_snapshot
      t.string :source_record_type
      t.bigint :source_record_id
      t.integer :vendor_priority_snapshot
      t.integer :estimated_unit_cost_cents_snapshot
      t.string :returnability_snapshot
      t.references :canceled_by_user, foreign_key: { to_table: :users }
      t.datetime :canceled_at
      t.text :cancel_reason
      t.text :notes
      t.timestamps
    end

    add_index :sourcing_attempts, %i[sourcing_run_id sequence_number],
              unique: true,
              name: "index_sourcing_attempts_on_run_and_sequence"
    add_index :sourcing_attempts, %i[demand_line_id status]
    add_index :sourcing_attempts, %i[store_id vendor_id status]
    add_check_constraint :sourcing_attempts, "quantity_requested > 0", name: "sourcing_attempts_quantity_positive"
  end
end
