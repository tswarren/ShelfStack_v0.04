# frozen_string_literal: true

class AddV0041ProductMetadataToProducts < ActiveRecord::Migration[8.1]
  def change
    change_table :products, bulk: true do |t|
      t.string :catalog_item_type
      t.string :title
      t.string :subtitle
      t.string :creators
      t.jsonb :creator_details
      t.string :publisher
      t.jsonb :publisher_details
      t.date :publication_date
      t.string :publication_status, null: false, default: "active"
      t.string :series_name
      t.string :series_enumeration, limit: 15
      t.jsonb :series_data
      t.references :format, foreign_key: true, index: true
      t.string :edition_statement
      t.string :language_code, limit: 10
      t.text :description
      t.string :year, limit: 4
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
      t.boolean :digital, null: false, default: false
      t.boolean :large_print, null: false, default: false
      t.integer :page_count
      t.integer :duration_minutes
      t.decimal :height, precision: 10, scale: 2
      t.decimal :width, precision: 10, scale: 2
      t.decimal :depth, precision: 10, scale: 2
      t.string :dimension_units
      t.decimal :weight, precision: 10, scale: 2
      t.string :weight_units
      t.references :store_category, foreign_key: { to_table: :category_nodes }, index: true
    end

    add_index :products, :title
    add_index :products, :publisher
    add_index :products, :publication_date
    add_index :products, :series_name
    add_index :products, :year
    add_index :products, :source

    add_check_constraint :products,
      "year IS NULL OR year ~ '^[0-9]{4}$'",
      name: "chk_products_year_format"
  end
end
