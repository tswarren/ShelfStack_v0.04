# frozen_string_literal: true

class AddGiftCardSaleToPosTransactionLines < ActiveRecord::Migration[8.0]
  def change
    change_table :pos_transaction_lines, bulk: true do |t|
      t.references :stored_value_account, foreign_key: true, null: true
      t.references :stored_value_identifier, foreign_key: true, null: true
      t.boolean :generate_stored_value_identifier, null: false, default: false
    end
  end
end
