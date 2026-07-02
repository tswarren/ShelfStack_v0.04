# frozen_string_literal: true

class AddV00410PosDemandAllocationLine < ActiveRecord::Migration[8.0]
  def change
    add_reference :pos_transaction_lines, :demand_allocation, foreign_key: true, index: true
  end
end
