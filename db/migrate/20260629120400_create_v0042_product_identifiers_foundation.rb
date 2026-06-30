# frozen_string_literal: true

class CreateV0042ProductIdentifiersFoundation < ActiveRecord::Migration[8.0]
  def change
    create_table :product_identifiers do |t|
      t.references :product, null: false, foreign_key: true

      t.string :validation_family, null: false
      t.string :identifier_value, null: false, limit: 100
      t.string :normalized_identifier, null: false, limit: 100

      t.string :display_label, limit: 100
      t.string :freeform_scope, limit: 50

      t.boolean :primary_identifier, null: false, default: false
      t.boolean :valid_check_digit
      t.string :validation_message

      t.string :source, null: false, default: "manual"
      t.boolean :active, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :product_identifiers,
      :normalized_identifier,
      unique: true,
      where: "active = true AND validation_family IN ('gtin', 'house')",
      name: "index_product_identifiers_unique_active_gtin_house"

    add_index :product_identifiers,
      [ :validation_family, :normalized_identifier ],
      unique: true,
      where: "active = true AND validation_family = 'isbn'",
      name: "index_product_identifiers_unique_active_isbn"

    add_index :product_identifiers,
      [ :product_id, :validation_family, :freeform_scope, :normalized_identifier ],
      unique: true,
      where: "active = true AND validation_family = 'freeform'",
      name: "index_product_identifiers_unique_active_freeform_per_product"

    add_index :product_identifiers,
      :product_id,
      unique: true,
      where: "active = true AND primary_identifier = true",
      name: "index_product_identifiers_one_active_primary_per_product"

    create_table :internal_ean_sequences do |t|
      t.string :segment, null: false, limit: 3
      t.string :purpose, null: false, limit: 50
      t.bigint :last_sequence, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :internal_ean_sequences, :segment, unique: true

    create_table :product_variant_lookup_codes do |t|
      t.references :product_variant, null: false, foreign_key: true
      t.references :store, null: true, foreign_key: true

      t.string :code, null: false, limit: 20
      t.string :normalized_code, null: false, limit: 20
      t.string :code_type, null: false, default: "manual", limit: 20

      t.boolean :active, null: false, default: true
      t.integer :priority, null: false, default: 0

      t.timestamps
    end

    add_index :product_variant_lookup_codes,
      [ :store_id, :normalized_code ],
      unique: true,
      where: "active = true AND store_id IS NOT NULL",
      name: "index_variant_lookup_codes_unique_active_store_code"

    add_index :product_variant_lookup_codes,
      :normalized_code,
      unique: true,
      where: "active = true AND store_id IS NULL",
      name: "index_variant_lookup_codes_unique_active_global_code"
  end
end
