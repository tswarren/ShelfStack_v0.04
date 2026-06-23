# frozen_string_literal: true

class AddStoredValueToPosTenders < ActiveRecord::Migration[8.0]
  def change
    change_table :pos_tenders, bulk: true do |t|
      t.references :stored_value_account, foreign_key: true, index: true
      t.references :stored_value_identifier, foreign_key: true, index: true
    end
  end
end
