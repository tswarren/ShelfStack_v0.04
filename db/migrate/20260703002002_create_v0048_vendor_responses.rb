# frozen_string_literal: true

class CreateV0048VendorResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :vendor_responses do |t|
      t.references :store, null: false, foreign_key: true
      t.references :sourcing_attempt, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: true
      t.string :response_status, null: false
      t.string :response_method, null: false, default: "manual"
      t.references :responded_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :responded_at, null: false
      t.string :vendor_reference
      t.text :message
      t.date :expected_ship_date
      t.date :expected_arrival_date
      t.integer :quantity_confirmed, null: false, default: 0
      t.integer :quantity_backordered, null: false, default: 0
      t.integer :quantity_unavailable, null: false, default: 0
      t.integer :quantity_canceled, null: false, default: 0
      t.integer :quantity_failed, null: false, default: 0
      t.integer :quantity_substitute_offered, null: false, default: 0
      t.boolean :final_response, null: false, default: false
      t.references :purchase_order_line, foreign_key: true
      t.text :notes
      t.jsonb :raw_payload
      t.timestamps
    end

    add_index :vendor_responses, %i[sourcing_attempt_id responded_at]
    add_index :vendor_responses, %i[store_id vendor_id responded_at]
  end
end
