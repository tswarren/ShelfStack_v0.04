# frozen_string_literal: true

class Phase8SnapshotCheckConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :pos_transaction_lines,
      "inventory_tracking_snapshot IS NULL OR inventory_tracking_snapshot IN ('inventory', 'non_inventory')",
      name: "pos_transaction_lines_inventory_tracking_snapshot_chk"

    add_check_constraint :pos_transaction_lines,
      "costing_method_snapshot IS NULL OR costing_method_snapshot IN (" \
      "'moving_average', 'unit_cost', 'receipt_cost', 'buyback_offer', 'margin_estimate', " \
      "'return_reversal', 'none', 'unknown')",
      name: "pos_transaction_lines_costing_method_snapshot_chk"
  end
end
