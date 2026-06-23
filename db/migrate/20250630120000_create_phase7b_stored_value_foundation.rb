# frozen_string_literal: true

class CreatePhase7bStoredValueFoundation < ActiveRecord::Migration[8.0]
  def change
    create_table :stored_value_reason_codes do |t|
      t.string :reason_key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :stored_value_reason_codes, :reason_key, unique: true

    create_table :stored_value_accounts do |t|
      t.references :issuing_store, null: false, foreign_key: { to_table: :stores }
      t.references :customer, foreign_key: true
      t.string :account_type, null: false
      t.string :holder_name_snapshot
      t.integer :current_balance_cents, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.text :notes

      t.timestamps
    end

    add_index :stored_value_accounts, :account_type

    create_table :stored_value_identifiers do |t|
      t.references :stored_value_account, null: false, foreign_key: true
      t.string :identifier_type, null: false
      t.string :display_value_masked
      t.string :lookup_digest, null: false
      t.boolean :active, null: false, default: true
      t.bigint :replaced_by_identifier_id

      t.timestamps
    end

    add_index :stored_value_identifiers, :lookup_digest, unique: true, where: "active = true",
              name: "index_sv_identifiers_on_active_lookup_digest"
    add_foreign_key :stored_value_identifiers, :stored_value_identifiers, column: :replaced_by_identifier_id

    create_table :stored_value_ledger_entries do |t|
      t.references :stored_value_account, null: false, foreign_key: true
      t.references :store, null: false, foreign_key: true
      t.string :entry_type, null: false
      t.integer :amount_delta_cents, null: false
      t.integer :balance_after_cents
      t.references :reason_code, foreign_key: { to_table: :stored_value_reason_codes }
      t.bigint :reverses_entry_id
      t.string :source_type
      t.bigint :source_id
      t.text :notes
      t.datetime :posted_at, null: false
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :stored_value_ledger_entries, %i[stored_value_account_id posted_at],
              name: "index_sv_ledger_on_account_posted_at"
    add_index :stored_value_ledger_entries, %i[store_id posted_at],
              name: "index_sv_ledger_on_store_posted_at"
    add_index :stored_value_ledger_entries, %i[source_type source_id],
              name: "index_sv_ledger_on_source"
    add_index :stored_value_ledger_entries, :reverses_entry_id
    add_foreign_key :stored_value_ledger_entries, :stored_value_ledger_entries, column: :reverses_entry_id

    create_table :stored_value_transfers do |t|
      t.references :from_account, null: false, foreign_key: { to_table: :stored_value_accounts }
      t.references :to_account, null: false, foreign_key: { to_table: :stored_value_accounts }
      t.integer :amount_cents, null: false
      t.references :transfer_out_entry, null: false, foreign_key: { to_table: :stored_value_ledger_entries }
      t.references :transfer_in_entry, null: false, foreign_key: { to_table: :stored_value_ledger_entries }
      t.references :reason_code, null: false, foreign_key: { to_table: :stored_value_reason_codes }
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
