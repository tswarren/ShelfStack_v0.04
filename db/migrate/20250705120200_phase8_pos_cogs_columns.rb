# frozen_string_literal: true

class Phase8PosCogsColumns < ActiveRecord::Migration[8.1]
  def change
    change_table :pos_transaction_lines, bulk: true do |t|
      t.integer :unit_cogs_cents
      t.integer :total_cogs_cents
      t.string :cogs_source
      t.string :costing_method_snapshot
      t.string :revenue_treatment
      t.boolean :cogs_estimated, null: false, default: false
    end

    add_check_constraint :pos_transaction_lines,
      "unit_cogs_cents IS NULL OR unit_cogs_cents >= 0",
      name: "pos_transaction_lines_unit_cogs_cents_chk"

    add_check_constraint :pos_transaction_lines,
      "cogs_source IS NULL OR cogs_source IN (" \
      "'moving_average', 'unit_cost', 'receipt_cost', 'buyback_offer', 'margin_estimate', " \
      "'return_reversal', 'none', 'unknown')",
      name: "pos_transaction_lines_cogs_source_chk"

    add_check_constraint :pos_transaction_lines,
      "revenue_treatment IS NULL OR revenue_treatment IN (" \
      "'merchandise', 'service', 'liability', 'passthrough', 'none')",
      name: "pos_transaction_lines_revenue_treatment_chk"
  end
end
