# frozen_string_literal: true

class CreatePhase852aTaxExceptionFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_exception_reasons do |t|
      t.string :reason_key, null: false
      t.string :name, null: false
      t.string :exception_type, null: false
      t.boolean :requires_note, null: false, default: false
      t.boolean :requires_certificate, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end

    add_index :tax_exception_reasons, :reason_key, unique: true
    add_index :tax_exception_reasons, :name, unique: true

    add_check_constraint :tax_exception_reasons,
                         "exception_type IN ('exemption', 'rate_override', 'both')",
                         name: "tax_exception_reasons_exception_type_chk"

    create_table :pos_tax_exemptions do |t|
      t.references :pos_transaction, null: false, foreign_key: true
      t.references :tax_exception_reason, null: false, foreign_key: true
      t.string :certificate_number
      t.text :note
      t.references :exempted_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :exempted_at, null: false
      t.references :voided_by_user, foreign_key: { to_table: :users }
      t.datetime :voided_at
      t.text :void_reason
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end

    add_index :pos_tax_exemptions,
              :pos_transaction_id,
              unique: true,
              where: "voided_at IS NULL",
              name: "index_pos_tax_exemptions_one_active_per_transaction"

    add_reference :pos_transaction_lines, :normal_tax_category, foreign_key: { to_table: :tax_categories }
    add_reference :pos_transaction_lines, :normal_store_tax_rate, foreign_key: { to_table: :store_tax_rates }
    add_column :pos_transaction_lines, :normal_tax_rate_bps, :integer
    add_column :pos_transaction_lines, :normal_tax_cents, :integer, null: false, default: 0
    add_column :pos_transaction_lines, :normal_tax_identifier_snapshot, :string, limit: 1
    add_column :pos_transaction_lines, :normal_store_tax_rate_short_name_snapshot, :string
    add_column :pos_transaction_lines, :applied_tax_source, :string

    add_check_constraint :pos_transaction_lines,
                         "applied_tax_source IS NULL OR applied_tax_source IN ('normal', 'non_taxable', 'transaction_exemption', 'sourced_return')",
                         name: "pos_transaction_lines_applied_tax_source_chk"

    add_column :pos_transactions, :normal_tax_cents, :integer, null: false, default: 0
  end
end
