# frozen_string_literal: true

class AddV00413ReceiptLineMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :receipt_line_matches do |t|
      t.references :store, null: false, foreign_key: true
      t.references :receipt, null: false, foreign_key: true
      t.references :receipt_line, null: false, foreign_key: true
      t.references :purchase_order, null: false, foreign_key: true
      t.references :purchase_order_line, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.integer :quantity_matched, null: false
      t.string :match_status, null: false, default: "proposed"
      t.string :match_source, null: false, default: "auto"
      t.references :matched_by_user, foreign_key: { to_table: :users }
      t.datetime :matched_at
      t.references :released_by_user, foreign_key: { to_table: :users }
      t.datetime :released_at
      t.text :release_reason
      t.string :idempotency_key
      t.text :notes
      t.timestamps
    end

    add_index :receipt_line_matches, %i[receipt_line_id purchase_order_line_id match_status],
              name: "idx_receipt_line_matches_line_po_status"
    add_index :receipt_line_matches, %i[receipt_id match_status]
    add_index :receipt_line_matches,
              %i[store_id idempotency_key],
              unique: true,
              where: "idempotency_key IS NOT NULL",
              name: "idx_receipt_line_matches_store_idempotency"
  end
end
