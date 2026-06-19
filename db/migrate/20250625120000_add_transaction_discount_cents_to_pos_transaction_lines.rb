# frozen_string_literal: true

class AddTransactionDiscountCentsToPosTransactionLines < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_transaction_lines, :transaction_discount_cents, :integer, null: false, default: 0
  end
end
