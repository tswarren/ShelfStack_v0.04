# frozen_string_literal: true

class AddInternalNotesToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :internal_notes, :text
  end
end
