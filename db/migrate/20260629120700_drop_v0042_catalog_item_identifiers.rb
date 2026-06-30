# frozen_string_literal: true

class DropV0042CatalogItemIdentifiers < ActiveRecord::Migration[8.0]
  def up
    drop_table :catalog_item_identifiers, if_exists: true
  end

  def down
    create_table :catalog_item_identifiers do |t|
      t.references :catalog_item, null: false, foreign_key: true
      t.string :identifier_type, null: false
      t.string :identifier_value, null: false
      t.string :normalized_identifier, null: false
      t.boolean :primary_identifier, null: false, default: false
      t.boolean :valid_check_digit
      t.string :validation_message
      t.string :source
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :catalog_item_identifiers, :normalized_identifier
    add_index :catalog_item_identifiers, :active
    add_index :catalog_item_identifiers,
              %i[identifier_type normalized_identifier],
              unique: true,
              where: "identifier_type IN ('isbn10','isbn13','ean','upc','gtin','local')",
              name: "idx_catalog_item_identifiers_standard_unique"
    add_index :catalog_item_identifiers, :catalog_item_id,
              unique: true,
              where: "active = true AND primary_identifier = true",
              name: "index_catalog_item_identifiers_one_active_primary"
  end
end
