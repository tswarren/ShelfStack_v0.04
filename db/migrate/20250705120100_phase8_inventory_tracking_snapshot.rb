# frozen_string_literal: true

class Phase8InventoryTrackingSnapshot < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_transaction_lines, :inventory_tracking_snapshot, :string
  end
end
