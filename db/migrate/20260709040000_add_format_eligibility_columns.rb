# frozen_string_literal: true

class AddFormatEligibilityColumns < ActiveRecord::Migration[8.0]
  def change
    change_table :formats, bulk: true do |t|
      t.string :catalog_item_type
      t.boolean :digital
      t.integer :sort_order, null: false, default: 0
    end

    add_index :formats, :catalog_item_type
    add_index :formats, [ :catalog_item_type, :digital, :active ], name: "index_formats_on_kind_digital_active"
  end
end
