# frozen_string_literal: true

class AddPosLineTaxRateSnapshots < ActiveRecord::Migration[8.0]
  def change
    add_reference :pos_transaction_lines, :store_tax_rate, foreign_key: true
    add_column :pos_transaction_lines, :tax_identifier_snapshot, :string, limit: 1
    add_column :pos_transaction_lines, :store_tax_rate_short_name_snapshot, :string
  end
end
