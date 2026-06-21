# frozen_string_literal: true

class CreatePhase65ExternalCatalogLookup < ActiveRecord::Migration[8.1]
  def change
    create_table :external_data_sources do |t|
      t.string :source_key, null: false
      t.string :name, null: false
      t.string :base_url, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_health_check_at
      t.string :last_health_check_status
      t.integer :last_plan_limit_total
      t.integer :last_plan_limit_spent
      t.integer :last_plan_limit_left
      t.jsonb :configuration_json, null: false, default: {}
      t.timestamps
    end
    add_index :external_data_sources, :source_key, unique: true

    create_table :external_lookup_requests do |t|
      t.references :external_data_source, null: false, foreign_key: true
      t.string :lookup_type, null: false
      t.string :query, null: false
      t.string :normalized_query
      t.string :request_path
      t.jsonb :request_params_json, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.integer :response_status_code
      t.string :error_code
      t.text :error_message
      t.references :requested_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :external_lookup_requests, %i[external_data_source_id lookup_type normalized_query],
              name: "index_external_lookup_requests_on_source_type_query"
    add_index :external_lookup_requests, :status
    add_index :external_lookup_requests, :created_at

    create_table :external_lookup_results do |t|
      t.references :external_lookup_request, null: false, foreign_key: true, index: true
      t.string :source_key, null: false
      t.string :external_identifier
      t.string :isbn10
      t.string :isbn13
      t.string :title
      t.string :subtitle
      t.jsonb :authors_snapshot, null: false, default: []
      t.jsonb :publisher_snapshot, null: false, default: {}
      t.string :date_published_snapshot
      t.string :binding_snapshot
      t.string :language_snapshot
      t.integer :pages
      t.integer :msrp_cents
      t.string :currency_code, limit: 3
      t.string :image_url
      t.text :synopsis
      t.text :excerpt
      t.jsonb :subjects_snapshot, null: false, default: []
      t.string :dewey_decimal_snapshot
      t.jsonb :dimensions_snapshot, null: false, default: {}
      t.jsonb :other_isbns_snapshot, null: false, default: []
      t.jsonb :raw_payload_json, null: false, default: {}
      t.decimal :confidence_score, precision: 5, scale: 4
      t.references :local_catalog_item, foreign_key: { to_table: :catalog_items }
      t.references :local_product, foreign_key: { to_table: :products }
      t.references :local_product_variant, foreign_key: { to_table: :product_variants }
      t.boolean :selected, null: false, default: false
      t.timestamps
    end
    add_index :external_lookup_results, %i[source_key external_identifier],
              name: "index_external_lookup_results_on_source_and_identifier"
    add_index :external_lookup_results, :isbn13
    add_index :external_lookup_results, :isbn10

    create_table :external_catalog_imports do |t|
      t.references :external_lookup_result, null: false, foreign_key: true, index: true
      t.references :external_data_source, null: false, foreign_key: true
      t.string :status, null: false
      t.string :action_type, null: false
      t.references :imported_by_user, null: false, foreign_key: { to_table: :users }
      t.references :catalog_item, foreign_key: true
      t.references :product, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.text :error_message
      t.jsonb :field_mapping_snapshot, null: false, default: {}
      t.jsonb :raw_payload_json, null: false, default: {}
      t.datetime :applied_at
      t.timestamps
    end
    add_index :external_catalog_imports, :applied_at
    add_index :external_catalog_imports,
              %i[external_lookup_result_id catalog_item_id action_type],
              unique: true,
              where: "status = 'applied' AND action_type IN ('create_catalog_item', 'link_existing_catalog_item', 'fill_blank_existing_catalog_item')",
              name: "index_external_catalog_imports_on_result_item_action_applied"
  end
end
