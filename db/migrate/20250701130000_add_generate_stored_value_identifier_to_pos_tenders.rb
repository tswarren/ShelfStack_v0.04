# frozen_string_literal: true

class AddGenerateStoredValueIdentifierToPosTenders < ActiveRecord::Migration[8.0]
  def change
    add_column :pos_tenders, :generate_stored_value_identifier, :boolean, default: false, null: false
  end
end
