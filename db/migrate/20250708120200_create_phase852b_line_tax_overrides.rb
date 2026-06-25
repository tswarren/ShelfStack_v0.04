# frozen_string_literal: true

class CreatePhase852bLineTaxOverrides < ActiveRecord::Migration[8.1]
  def up
    create_table :pos_line_tax_overrides do |t|
      t.references :pos_transaction, null: false, foreign_key: true
      t.references :pos_transaction_line, null: false, foreign_key: true
      t.references :tax_exception_reason, null: false, foreign_key: true
      t.references :override_tax_category, null: false, foreign_key: { to_table: :tax_categories }
      t.references :override_store_tax_rate, null: false, foreign_key: { to_table: :store_tax_rates }
      t.integer :override_tax_rate_bps, null: false
      t.string :override_tax_identifier_snapshot, limit: 1
      t.string :override_store_tax_rate_short_name_snapshot
      t.text :note
      t.references :overridden_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :overridden_at, null: false
      t.references :voided_by_user, foreign_key: { to_table: :users }
      t.datetime :voided_at
      t.text :void_reason
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end

    add_index :pos_line_tax_overrides,
              :pos_transaction_line_id,
              unique: true,
              where: "voided_at IS NULL",
              name: "index_pos_line_tax_overrides_one_active_per_line"

    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_applied_tax_source_chk"
    add_check_constraint :pos_transaction_lines,
                         "applied_tax_source IS NULL OR applied_tax_source IN ('normal', 'non_taxable', 'transaction_exemption', 'sourced_return', 'line_override')",
                         name: "pos_transaction_lines_applied_tax_source_chk"
  end

  def down
    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_applied_tax_source_chk"
    add_check_constraint :pos_transaction_lines,
                         "applied_tax_source IS NULL OR applied_tax_source IN ('normal', 'non_taxable', 'transaction_exemption', 'sourced_return')",
                         name: "pos_transaction_lines_applied_tax_source_chk"

    drop_table :pos_line_tax_overrides
  end
end
