# frozen_string_literal: true

class CreatePhase6PosFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :pos_workstation_sequences do |t|
      t.references :workstation, null: false, foreign_key: true, index: { unique: true }
      t.integer :last_sequence, null: false, default: 0
      t.timestamps
    end

    create_table :pos_register_sessions do |t|
      t.references :store, null: false, foreign_key: true
      t.references :workstation, null: false, foreign_key: true
      t.references :opened_by_user, null: false, foreign_key: { to_table: :users }
      t.references :closed_by_user, foreign_key: { to_table: :users }
      t.string :status, null: false
      t.date :business_date, null: false
      t.integer :opening_cash_cents, null: false, default: 0
      t.integer :expected_closing_cash_cents
      t.integer :counted_closing_cash_cents
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.boolean :force_closed, null: false, default: false
      t.text :notes
      t.timestamps
    end

    add_index :pos_register_sessions, %i[store_id business_date]
    add_index :pos_register_sessions, %i[workstation_id opened_at]
    add_index :pos_register_sessions, :workstation_id,
              unique: true,
              where: "status = 'open'",
              name: "index_pos_register_sessions_one_open_per_workstation"

    create_table :pos_transactions do |t|
      t.references :store, null: false, foreign_key: true
      t.references :workstation, null: false, foreign_key: true
      t.references :user_session, foreign_key: true
      t.references :pos_register_session, foreign_key: true
      t.references :cashier_user, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false
      t.string :transaction_type
      t.string :transaction_number
      t.date :business_date
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :discount_cents, null: false, default: 0
      t.integer :tax_cents, null: false, default: 0
      t.integer :rounding_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.text :notes
      t.datetime :suspended_at
      t.datetime :completed_at
      t.datetime :voided_at
      t.timestamps
    end

    add_index :pos_transactions, :transaction_number, unique: true, where: "transaction_number IS NOT NULL"
    add_index :pos_transactions, %i[workstation_id transaction_number],
              unique: true,
              where: "transaction_number IS NOT NULL",
              name: "index_pos_transactions_on_workstation_and_number"
    add_index :pos_transactions, %i[store_id business_date status]
    add_index :pos_transactions, %i[store_id completed_at]

    create_table :pos_transaction_lines do |t|
      t.references :pos_transaction, null: false, foreign_key: true
      t.integer :line_number, null: false
      t.string :line_type, null: false
      t.references :product_variant, foreign_key: true
      t.references :product, foreign_key: true
      t.integer :quantity, null: false
      t.integer :unit_price_cents, null: false
      t.integer :line_discount_cents, null: false, default: 0
      t.integer :extended_price_cents, null: false, default: 0
      t.integer :tax_cents, null: false, default: 0
      t.string :product_sku_snapshot
      t.string :variant_sku_snapshot
      t.string :product_name_snapshot
      t.string :variant_name_snapshot
      t.string :open_ring_description
      t.references :sub_department, foreign_key: true
      t.references :tax_category, foreign_key: true
      t.integer :tax_rate_bps
      t.string :inventory_behavior_snapshot
      t.string :return_disposition
      t.references :source_transaction, foreign_key: { to_table: :pos_transactions }
      t.references :source_transaction_line, foreign_key: { to_table: :pos_transaction_lines }
      t.integer :source_sold_quantity_snapshot
      t.timestamps
    end

    add_index :pos_transaction_lines, %i[pos_transaction_id line_number],
              unique: true,
              name: "index_pos_transaction_lines_on_transaction_and_line_number"

    create_table :pos_tenders do |t|
      t.references :pos_transaction, null: false, foreign_key: true
      t.string :tender_type, null: false
      t.integer :amount_cents, null: false
      t.string :reference_number
      t.references :reverses_tender, foreign_key: { to_table: :pos_tenders }
      t.timestamps
    end

    create_table :pos_receipts do |t|
      t.references :pos_transaction, null: false, foreign_key: true, index: { unique: true }
      t.references :store, null: false, foreign_key: true
      t.string :receipt_number, null: false
      t.datetime :issued_at, null: false
      t.integer :reprint_count, null: false, default: 0
      t.timestamps
    end

    add_index :pos_receipts, :receipt_number, unique: true

    create_table :pos_authorizations do |t|
      t.references :store, null: false, foreign_key: true
      t.references :pos_transaction, foreign_key: true
      t.references :pos_register_session, foreign_key: true
      t.string :authorization_type, null: false
      t.references :requested_by_user, null: false, foreign_key: { to_table: :users }
      t.references :granted_by_user, foreign_key: { to_table: :users }
      t.datetime :granted_at
      t.datetime :denied_at
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end

    create_table :pos_voids do |t|
      t.references :pos_transaction, null: false, foreign_key: true, index: { unique: true }
      t.references :store, null: false, foreign_key: true
      t.references :workstation, null: false, foreign_key: true
      t.references :pos_register_session, null: false, foreign_key: true
      t.references :voided_by_user, null: false, foreign_key: { to_table: :users }
      t.references :pos_authorization, foreign_key: true
      t.datetime :voided_at, null: false
      t.date :business_date, null: false
      t.string :reason_code
      t.text :notes
      t.timestamps
    end

    create_table :pos_cash_movements do |t|
      t.references :pos_register_session, null: false, foreign_key: true
      t.references :store, null: false, foreign_key: true
      t.string :movement_type, null: false
      t.integer :amount_cents, null: false
      t.string :reason_code
      t.text :notes
      t.references :recorded_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :recorded_at, null: false
      t.timestamps
    end
  end
end
