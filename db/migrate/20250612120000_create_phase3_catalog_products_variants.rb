# frozen_string_literal: true

class CreatePhase3CatalogProductsVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :formats do |t|
      t.string :format_key, null: false, limit: 30
      t.string :name, null: false
      t.string :short_name, null: false, limit: 20
      t.string :code, limit: 20
      t.boolean :virtual, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :formats, :format_key, unique: true
    add_index :formats, :short_name
    add_index :formats, :code
    add_index :formats, :active

    create_table :catalog_items do |t|
      t.string :catalog_item_type, null: false
      t.string :title, null: false
      t.string :creators
      t.jsonb :creator_details
      t.string :publisher
      t.jsonb :publisher_details
      t.date :publication_date
      t.string :publication_status, null: false, default: "active"
      t.string :series_name
      t.string :series_enumeration, limit: 15
      t.jsonb :series_data
      t.references :format, null: false, foreign_key: true, index: true
      t.string :edition_statement
      t.string :language_code, limit: 10
      t.decimal :height, precision: 10, scale: 2
      t.decimal :width, precision: 10, scale: 2
      t.decimal :depth, precision: 10, scale: 2
      t.string :dimension_units
      t.decimal :weight, precision: 10, scale: 2
      t.string :weight_units
      t.integer :page_count
      t.integer :duration_minutes
      t.boolean :large_print, null: false, default: false
      t.string :bisac_subjects
      t.jsonb :bisac_subject_data
      t.string :genres
      t.jsonb :genre_data
      t.string :themes
      t.jsonb :theme_data
      t.string :target_audiences
      t.jsonb :target_audience_data
      t.string :access_restrictions
      t.jsonb :access_restriction_data
      t.string :publication_frequency
      t.text :description
      t.string :year, limit: 4
      t.boolean :digital, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :catalog_items, :catalog_item_type
    add_index :catalog_items, :title
    add_index :catalog_items, :publisher
    add_index :catalog_items, :publication_status
    add_index :catalog_items, :series_name
    add_index :catalog_items, :year
    add_index :catalog_items, :active
    add_check_constraint :catalog_items,
                         "year IS NULL OR year ~ '^[0-9]{4}$'",
                         name: "chk_catalog_items_year_format"

    create_table :catalog_item_identifiers do |t|
      t.references :catalog_item, null: false, foreign_key: true, index: true
      t.string :identifier_type, null: false
      t.string :identifier_value, null: false, limit: 100
      t.string :normalized_identifier, null: false, limit: 100
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
              where: "identifier_type IN ('isbn10', 'isbn13', 'ean', 'upc', 'gtin', 'local')",
              name: "idx_catalog_item_identifiers_standard_unique"
    add_index :catalog_item_identifiers, :catalog_item_id,
              unique: true,
              where: "active = true AND primary_identifier = true",
              name: "index_catalog_item_identifiers_one_active_primary"

    create_table :display_locations do |t|
      t.string :name, null: false
      t.string :short_name, null: false, limit: 20
      t.references :parent, foreign_key: { to_table: :display_locations }, index: true
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :display_locations, :short_name, unique: true
    add_index :display_locations, :sort_order
    add_index :display_locations, :active

    create_table :store_display_locations do |t|
      t.references :display_location, null: false, foreign_key: true, index: true
      t.references :store, null: false, foreign_key: true, index: true
      t.integer :linear_feet, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :store_display_locations, %i[store_id display_location_id], unique: true,
              name: "index_store_display_locations_unique"
    add_index :store_display_locations, :active

    create_table :products do |t|
      t.references :catalog_item, foreign_key: true, index: true
      t.string :name, null: false
      t.string :name_override
      t.string :short_name, limit: 40
      t.string :sku, null: false, limit: 50
      t.string :product_type, null: false, default: "physical"
      t.string :variation_type, null: false, default: "standard"
      t.integer :list_price_cents, null: false, default: 0
      t.references :default_display_location, foreign_key: { to_table: :display_locations }, index: true
      t.string :variant1_label
      t.string :variant2_label
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :products, :sku, unique: true
    add_index :products, :name
    add_index :products, :product_type
    add_index :products, :variation_type
    add_index :products, :active
    add_check_constraint :products, "list_price_cents >= 0", name: "chk_products_list_price_cents"

    create_table :product_conditions do |t|
      t.string :condition_key, null: false
      t.string :name, null: false
      t.string :short_name, null: false, limit: 20
      t.string :sku_component, limit: 5
      t.integer :sort_order, null: false, default: 0
      t.boolean :new_condition, null: false, default: false
      t.integer :default_list_price_factor_bps, null: false, default: 10_000
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :product_conditions, :condition_key, unique: true
    add_index :product_conditions, :short_name, unique: true
    add_index :product_conditions, :sku_component, unique: true, where: "sku_component IS NOT NULL",
              name: "idx_product_conditions_sku_component_unique"
    add_index :product_conditions, :sort_order
    add_index :product_conditions, :new_condition
    add_index :product_conditions, :active
    add_check_constraint :product_conditions,
                         "default_list_price_factor_bps >= 0 AND default_list_price_factor_bps <= 10000",
                         name: "chk_product_conditions_list_price_factor"

    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :name_override
      t.string :short_name, limit: 40
      t.string :sku, null: false, limit: 50
      t.references :condition, foreign_key: { to_table: :product_conditions }, index: true
      t.references :category, null: false, foreign_key: true, index: true
      t.references :display_location, foreign_key: true, index: true
      t.string :attribute1_value
      t.string :attribute1_sku_component, limit: 5
      t.string :attribute2_value
      t.string :attribute2_sku_component, limit: 5
      t.integer :selling_price_cents, null: false, default: 0
      t.string :pricing_model_override
      t.string :inventory_behavior, null: false, default: "standard_physical"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :product_variants, :sku, unique: true
    add_index :product_variants, :inventory_behavior
    add_index :product_variants, :pricing_model_override
    add_index :product_variants, :active
    add_check_constraint :product_variants, "selling_price_cents >= 0",
                         name: "chk_product_variants_selling_price_cents"

    create_table :vendors do |t|
      t.string :name, null: false
      t.references :parent_vendor, foreign_key: { to_table: :vendors }, index: true
      t.string :default_pricing_model
      t.integer :default_margin_target_bps
      t.integer :default_supplier_discount_bps
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :vendors, :name
    add_index :vendors, :default_pricing_model
    add_index :vendors, :active
  end
end
