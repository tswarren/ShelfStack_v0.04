# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_11_010732) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.bigint "actor_user_id", null: false
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.jsonb "event_details", default: {}, null: false
    t.string "event_name", null: false
    t.datetime "occurred_at", null: false
    t.bigint "source_id"
    t.string "source_type"
    t.bigint "store_id"
    t.datetime "updated_at", null: false
    t.bigint "user_session_id"
    t.bigint "workstation_id"
    t.index ["actor_user_id"], name: "index_audit_events_on_actor_user_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable_type_and_auditable_id"
    t.index ["event_name"], name: "index_audit_events_on_event_name"
    t.index ["occurred_at"], name: "index_audit_events_on_occurred_at"
    t.index ["source_type", "source_id"], name: "index_audit_events_on_source_type_and_source_id"
    t.index ["store_id", "occurred_at"], name: "index_audit_events_on_store_id_and_occurred_at"
    t.index ["store_id"], name: "index_audit_events_on_store_id"
    t.index ["user_session_id"], name: "index_audit_events_on_user_session_id"
    t.index ["workstation_id"], name: "index_audit_events_on_workstation_id"
  end

  create_table "catalog_item_identifiers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "catalog_item_id", null: false
    t.datetime "created_at", null: false
    t.string "identifier_type", null: false
    t.string "identifier_value", limit: 100, null: false
    t.string "normalized_identifier", limit: 100, null: false
    t.boolean "primary_identifier", default: false, null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.boolean "valid_check_digit"
    t.string "validation_message"
    t.index ["active"], name: "index_catalog_item_identifiers_on_active"
    t.index ["catalog_item_id"], name: "index_catalog_item_identifiers_on_catalog_item_id"
    t.index ["catalog_item_id"], name: "index_catalog_item_identifiers_one_active_primary", unique: true, where: "((active = true) AND (primary_identifier = true))"
    t.index ["identifier_type", "normalized_identifier"], name: "idx_catalog_item_identifiers_standard_unique", unique: true, where: "((identifier_type)::text = ANY (ARRAY[('isbn10'::character varying)::text, ('isbn13'::character varying)::text, ('ean'::character varying)::text, ('upc'::character varying)::text, ('gtin'::character varying)::text, ('local'::character varying)::text]))"
    t.index ["normalized_identifier"], name: "index_catalog_item_identifiers_on_normalized_identifier"
  end

  create_table "catalog_items", force: :cascade do |t|
    t.jsonb "access_restriction_data"
    t.string "access_restrictions"
    t.boolean "active", default: true, null: false
    t.jsonb "bisac_subject_data"
    t.string "bisac_subjects"
    t.string "catalog_item_type", null: false
    t.datetime "created_at", null: false
    t.jsonb "creator_details"
    t.string "creators"
    t.decimal "depth", precision: 10, scale: 2
    t.text "description"
    t.boolean "digital", default: false, null: false
    t.string "dimension_units"
    t.integer "duration_minutes"
    t.string "edition_statement"
    t.bigint "format_id", null: false
    t.jsonb "genre_data"
    t.string "genres"
    t.decimal "height", precision: 10, scale: 2
    t.string "language_code", limit: 10
    t.boolean "large_print", default: false, null: false
    t.integer "page_count"
    t.date "publication_date"
    t.string "publication_frequency"
    t.string "publication_status", default: "active", null: false
    t.string "publisher"
    t.jsonb "publisher_details"
    t.jsonb "series_data"
    t.string "series_enumeration", limit: 15
    t.string "series_name"
    t.bigint "store_category_id"
    t.jsonb "target_audience_data"
    t.string "target_audiences"
    t.jsonb "theme_data"
    t.string "themes"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 10, scale: 2
    t.string "weight_units"
    t.decimal "width", precision: 10, scale: 2
    t.string "year", limit: 4
    t.index ["active"], name: "index_catalog_items_on_active"
    t.index ["catalog_item_type"], name: "index_catalog_items_on_catalog_item_type"
    t.index ["format_id"], name: "index_catalog_items_on_format_id"
    t.index ["publication_status"], name: "index_catalog_items_on_publication_status"
    t.index ["publisher"], name: "index_catalog_items_on_publisher"
    t.index ["series_name"], name: "index_catalog_items_on_series_name"
    t.index ["store_category_id"], name: "index_catalog_items_on_store_category_id"
    t.index ["title"], name: "index_catalog_items_on_title"
    t.index ["year"], name: "index_catalog_items_on_year"
    t.check_constraint "year IS NULL OR year::text ~ '^[0-9]{4}$'::text", name: "chk_catalog_items_year_format"
  end

  create_table "categorizations", force: :cascade do |t|
    t.bigint "categorizable_id", null: false
    t.string "categorizable_type", null: false
    t.bigint "category_node_id", null: false
    t.datetime "created_at", null: false
    t.boolean "primary", default: false, null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["categorizable_type", "categorizable_id", "category_node_id"], name: "index_categorizations_on_categorizable_and_node", unique: true
    t.index ["categorizable_type", "categorizable_id"], name: "index_categorizations_on_categorizable"
    t.index ["category_node_id"], name: "index_categorizations_on_category_node_id"
  end

  create_table "category_nodes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "category_scheme_id", null: false
    t.datetime "created_at", null: false
    t.bigint "default_display_location_id"
    t.bigint "default_sub_department_id"
    t.string "name", null: false
    t.string "node_key", null: false
    t.bigint "parent_id"
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["category_scheme_id", "node_key"], name: "index_category_nodes_on_category_scheme_id_and_node_key", unique: true
    t.index ["category_scheme_id", "parent_id", "name"], name: "index_category_nodes_on_scheme_parent_and_name", unique: true, where: "(parent_id IS NOT NULL)"
    t.index ["category_scheme_id"], name: "index_category_nodes_on_category_scheme_id"
    t.index ["default_display_location_id"], name: "index_category_nodes_on_default_display_location_id"
    t.index ["default_sub_department_id"], name: "index_category_nodes_on_default_sub_department_id"
    t.index ["parent_id"], name: "index_category_nodes_on_parent_id"
  end

  create_table "category_schemes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "purpose", null: false
    t.string "scheme_key", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_category_schemes_on_name", unique: true
    t.index ["scheme_key"], name: "index_category_schemes_on_scheme_key", unique: true
  end

  create_table "departments", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "department_number", limit: 3, null: false
    t.text "description"
    t.string "gl_account_code", limit: 20
    t.string "name", null: false
    t.string "short_name", limit: 20, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_departments_on_active"
    t.index ["department_number"], name: "index_departments_on_department_number", unique: true
    t.index ["gl_account_code"], name: "index_departments_on_gl_account_code"
    t.index ["name"], name: "index_departments_on_name", unique: true
    t.index ["short_name"], name: "index_departments_on_short_name", unique: true
  end

  create_table "display_locations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.string "short_name", limit: 20, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_display_locations_on_active"
    t.index ["parent_id"], name: "index_display_locations_on_parent_id"
    t.index ["short_name"], name: "index_display_locations_on_short_name", unique: true
    t.index ["sort_order"], name: "index_display_locations_on_sort_order"
  end

  create_table "formats", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", limit: 20
    t.datetime "created_at", null: false
    t.string "format_key", limit: 30, null: false
    t.string "name", null: false
    t.string "short_name", limit: 20, null: false
    t.datetime "updated_at", null: false
    t.boolean "virtual", default: false, null: false
    t.index ["active"], name: "index_formats_on_active"
    t.index ["code"], name: "index_formats_on_code"
    t.index ["format_key"], name: "index_formats_on_format_key", unique: true
    t.index ["short_name"], name: "index_formats_on_short_name"
  end

  create_table "inventory_adjustment_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inventory_adjustment_id", null: false
    t.bigint "inventory_location_id"
    t.bigint "inventory_reason_code_id"
    t.integer "line_number", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity_delta", null: false
    t.integer "unit_cost_cents"
    t.datetime "updated_at", null: false
    t.index ["inventory_adjustment_id", "line_number"], name: "idx_inventory_adjustment_lines_adjustment_line_number", unique: true
    t.index ["inventory_adjustment_id"], name: "index_inventory_adjustment_lines_on_inventory_adjustment_id"
    t.index ["inventory_location_id"], name: "index_inventory_adjustment_lines_on_inventory_location_id"
    t.index ["inventory_reason_code_id"], name: "index_inventory_adjustment_lines_on_inventory_reason_code_id"
    t.index ["product_variant_id"], name: "index_inventory_adjustment_lines_on_product_variant_id"
  end

  create_table "inventory_adjustments", force: :cascade do |t|
    t.string "adjustment_type", null: false
    t.datetime "created_at", null: false
    t.bigint "inventory_posting_id"
    t.text "notes"
    t.datetime "posted_at"
    t.bigint "posted_by_user_id"
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["adjustment_type"], name: "index_inventory_adjustments_on_adjustment_type"
    t.index ["inventory_posting_id"], name: "index_inventory_adjustments_on_inventory_posting_id"
    t.index ["posted_by_user_id"], name: "index_inventory_adjustments_on_posted_by_user_id"
    t.index ["store_id", "status"], name: "index_inventory_adjustments_on_store_id_and_status"
    t.index ["store_id"], name: "index_inventory_adjustments_on_store_id"
  end

  create_table "inventory_balances", force: :cascade do |t|
    t.string "cost_source"
    t.datetime "created_at", null: false
    t.integer "inventory_cost_value_cents", default: 0, null: false
    t.integer "inventory_retail_value_cents", default: 0, null: false
    t.bigint "last_posting_id"
    t.integer "moving_average_unit_cost_cents"
    t.bigint "product_variant_id", null: false
    t.integer "quantity_available", default: 0, null: false
    t.integer "quantity_on_hand", default: 0, null: false
    t.string "retail_source"
    t.bigint "store_id", null: false
    t.integer "unit_cost_cents"
    t.integer "unit_retail_cents"
    t.datetime "updated_at", null: false
    t.index ["last_posting_id"], name: "index_inventory_balances_on_last_posting_id"
    t.index ["product_variant_id"], name: "index_inventory_balances_on_product_variant_id"
    t.index ["store_id", "product_variant_id"], name: "index_inventory_balances_on_store_id_and_product_variant_id", unique: true
    t.index ["store_id", "quantity_on_hand"], name: "idx_inventory_balances_store_quantity_on_hand"
    t.index ["store_id"], name: "index_inventory_balances_on_store_id"
    t.check_constraint "moving_average_unit_cost_cents IS NULL OR moving_average_unit_cost_cents >= 0", name: "chk_inventory_balances_moving_average_unit_cost_cents"
  end

  create_table "inventory_ledger_entries", force: :cascade do |t|
    t.string "cost_source", null: false
    t.datetime "created_at", null: false
    t.bigint "inventory_location_id"
    t.bigint "inventory_posting_id", null: false
    t.bigint "inventory_reason_code_id"
    t.integer "line_number", null: false
    t.string "movement_type", null: false
    t.datetime "occurred_at", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity_delta", null: false
    t.string "retail_source", null: false
    t.bigint "store_id", null: false
    t.integer "total_cost_cents"
    t.integer "total_retail_cents"
    t.integer "unit_cost_cents"
    t.integer "unit_retail_cents"
    t.datetime "updated_at", null: false
    t.index ["inventory_location_id"], name: "index_inventory_ledger_entries_on_inventory_location_id"
    t.index ["inventory_posting_id", "line_number"], name: "idx_inventory_ledger_entries_posting_line_number", unique: true
    t.index ["inventory_posting_id"], name: "index_inventory_ledger_entries_on_inventory_posting_id"
    t.index ["inventory_reason_code_id"], name: "index_inventory_ledger_entries_on_inventory_reason_code_id"
    t.index ["product_variant_id", "occurred_at"], name: "idx_inventory_ledger_entries_variant_occurred_at"
    t.index ["product_variant_id"], name: "index_inventory_ledger_entries_on_product_variant_id"
    t.index ["store_id", "product_variant_id"], name: "idx_inventory_ledger_entries_store_variant"
    t.index ["store_id"], name: "index_inventory_ledger_entries_on_store_id"
  end

  create_table "inventory_locations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "short_name", limit: 40, null: false
    t.integer "sort_order", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_inventory_locations_on_active"
    t.index ["store_id", "short_name"], name: "index_inventory_locations_on_store_id_and_short_name", unique: true
    t.index ["store_id"], name: "index_inventory_locations_on_store_id"
  end

  create_table "inventory_postings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "idempotency_key", null: false
    t.text "notes"
    t.datetime "posted_at", null: false
    t.bigint "posted_by_user_id", null: false
    t.string "posting_type", null: false
    t.bigint "reversal_of_posting_id"
    t.bigint "reversed_by_posting_id"
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "workstation_id"
    t.index ["idempotency_key"], name: "index_inventory_postings_on_idempotency_key", unique: true
    t.index ["posted_by_user_id"], name: "index_inventory_postings_on_posted_by_user_id"
    t.index ["posting_type"], name: "index_inventory_postings_on_posting_type"
    t.index ["reversal_of_posting_id"], name: "index_inventory_postings_on_reversal_of_posting_id"
    t.index ["reversed_by_posting_id"], name: "index_inventory_postings_on_reversed_by_posting_id"
    t.index ["source_type", "source_id"], name: "index_inventory_postings_on_source_type_and_source_id", unique: true
    t.index ["store_id", "posted_at"], name: "index_inventory_postings_on_store_id_and_posted_at"
    t.index ["store_id"], name: "index_inventory_postings_on_store_id"
    t.index ["workstation_id"], name: "index_inventory_postings_on_workstation_id"
  end

  create_table "inventory_reason_codes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "reason_key", limit: 40, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_inventory_reason_codes_on_active"
    t.index ["name"], name: "index_inventory_reason_codes_on_name", unique: true
    t.index ["reason_key"], name: "index_inventory_reason_codes_on_reason_key", unique: true
  end

  create_table "permissions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "permission_group", null: false
    t.string "permission_key", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_permissions_on_active"
    t.index ["permission_group"], name: "index_permissions_on_permission_group"
    t.index ["permission_key"], name: "index_permissions_on_permission_key", unique: true
  end

  create_table "product_conditions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "condition_key", null: false
    t.datetime "created_at", null: false
    t.integer "default_list_price_factor_bps", default: 10000, null: false
    t.text "description"
    t.string "name", null: false
    t.boolean "new_condition", default: false, null: false
    t.string "short_name", limit: 20, null: false
    t.string "sku_component", limit: 5
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_product_conditions_on_active"
    t.index ["condition_key"], name: "index_product_conditions_on_condition_key", unique: true
    t.index ["new_condition"], name: "index_product_conditions_on_new_condition"
    t.index ["short_name"], name: "index_product_conditions_on_short_name", unique: true
    t.index ["sku_component"], name: "idx_product_conditions_sku_component_unique", unique: true, where: "(sku_component IS NOT NULL)"
    t.index ["sort_order"], name: "index_product_conditions_on_sort_order"
    t.check_constraint "default_list_price_factor_bps >= 0 AND default_list_price_factor_bps <= 10000", name: "chk_product_conditions_list_price_factor"
  end

  create_table "product_variant_vendors", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "preferred", default: false, null: false
    t.bigint "product_variant_id", null: false
    t.string "returnability_status"
    t.integer "supplier_discount_bps"
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.string "vendor_item_number"
    t.index ["active"], name: "index_product_variant_vendors_on_active"
    t.index ["product_variant_id", "vendor_id"], name: "idx_product_variant_vendors_variant_vendor", unique: true
    t.index ["product_variant_id"], name: "index_product_variant_vendors_on_product_variant_id"
    t.index ["vendor_id"], name: "index_product_variant_vendors_on_vendor_id"
    t.check_constraint "returnability_status IS NULL OR (returnability_status::text = ANY (ARRAY['returnable'::character varying, 'non_returnable'::character varying, 'conditional'::character varying, 'unknown'::character varying]::text[]))", name: "chk_product_variant_vendors_returnability_status"
    t.check_constraint "supplier_discount_bps IS NULL OR supplier_discount_bps >= 0 AND supplier_discount_bps <= 10000", name: "chk_product_variant_vendors_supplier_discount_bps"
  end

  create_table "product_variants", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "attribute1_sku_component", limit: 5
    t.string "attribute1_value"
    t.string "attribute2_sku_component", limit: 5
    t.string "attribute2_value"
    t.bigint "condition_id"
    t.datetime "created_at", null: false
    t.bigint "display_location_id"
    t.string "inventory_behavior", default: "standard_physical", null: false
    t.string "name", null: false
    t.string "name_override"
    t.string "pricing_model_override"
    t.bigint "product_id", null: false
    t.string "returnability_status", default: "unknown", null: false
    t.integer "selling_price_cents", default: 0, null: false
    t.string "short_name", limit: 40
    t.string "sku", limit: 50, null: false
    t.bigint "sub_department_id", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_product_variants_on_active"
    t.index ["condition_id"], name: "index_product_variants_on_condition_id"
    t.index ["display_location_id"], name: "index_product_variants_on_display_location_id"
    t.index ["inventory_behavior"], name: "index_product_variants_on_inventory_behavior"
    t.index ["pricing_model_override"], name: "index_product_variants_on_pricing_model_override"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
    t.index ["sub_department_id"], name: "index_product_variants_on_sub_department_id"
    t.check_constraint "returnability_status::text = ANY (ARRAY['returnable'::character varying, 'non_returnable'::character varying, 'conditional'::character varying, 'unknown'::character varying]::text[])", name: "chk_product_variants_returnability_status"
    t.check_constraint "selling_price_cents >= 0", name: "chk_product_variants_selling_price_cents"
  end

  create_table "product_vendors", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "preferred", default: false, null: false
    t.bigint "product_id", null: false
    t.string "returnability_status"
    t.integer "supplier_discount_bps"
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.string "vendor_item_number"
    t.index ["active"], name: "index_product_vendors_on_active"
    t.index ["product_id", "vendor_id"], name: "index_product_vendors_on_product_id_and_vendor_id", unique: true
    t.index ["product_id"], name: "index_product_vendors_on_product_id"
    t.index ["vendor_id"], name: "index_product_vendors_on_vendor_id"
    t.check_constraint "returnability_status IS NULL OR (returnability_status::text = ANY (ARRAY['returnable'::character varying, 'non_returnable'::character varying, 'conditional'::character varying, 'unknown'::character varying]::text[]))", name: "chk_product_vendors_returnability_status"
    t.check_constraint "supplier_discount_bps IS NULL OR supplier_discount_bps >= 0 AND supplier_discount_bps <= 10000", name: "chk_product_vendors_supplier_discount_bps"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "catalog_item_id"
    t.datetime "created_at", null: false
    t.bigint "default_display_location_id"
    t.bigint "default_sub_department_id"
    t.integer "list_price_cents", default: 0, null: false
    t.string "name", null: false
    t.string "name_override"
    t.string "product_type", default: "physical", null: false
    t.string "short_name", limit: 40
    t.string "sku", limit: 50, null: false
    t.datetime "updated_at", null: false
    t.string "variant1_label"
    t.string "variant2_label"
    t.string "variation_type", default: "standard", null: false
    t.index ["active"], name: "index_products_on_active"
    t.index ["catalog_item_id"], name: "index_products_on_catalog_item_id"
    t.index ["default_display_location_id"], name: "index_products_on_default_display_location_id"
    t.index ["default_sub_department_id"], name: "index_products_on_default_sub_department_id"
    t.index ["name"], name: "index_products_on_name"
    t.index ["product_type"], name: "index_products_on_product_type"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["variation_type"], name: "index_products_on_variation_type"
    t.check_constraint "list_price_cents >= 0", name: "chk_products_list_price_cents"
  end

  create_table "purchase_order_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "line_number", null: false
    t.bigint "product_variant_id", null: false
    t.bigint "product_variant_vendor_id"
    t.bigint "purchase_order_id", null: false
    t.integer "quantity_ordered", null: false
    t.integer "quantity_received", default: 0, null: false
    t.string "returnability_status_snapshot"
    t.string "status", default: "open", null: false
    t.integer "supplier_discount_bps"
    t.integer "unit_cost_cents"
    t.integer "unit_list_price_cents"
    t.datetime "updated_at", null: false
    t.string "variant_name_snapshot"
    t.string "variant_sku_snapshot"
    t.bigint "vendor_id", null: false
    t.string "vendor_item_number_snapshot"
    t.index ["product_variant_id"], name: "index_purchase_order_lines_on_product_variant_id"
    t.index ["product_variant_vendor_id"], name: "index_purchase_order_lines_on_product_variant_vendor_id"
    t.index ["purchase_order_id", "line_number"], name: "idx_purchase_order_lines_order_line_number", unique: true
    t.index ["purchase_order_id"], name: "index_purchase_order_lines_on_purchase_order_id"
    t.index ["vendor_id"], name: "index_purchase_order_lines_on_vendor_id"
    t.check_constraint "quantity_ordered > 0", name: "chk_purchase_order_lines_quantity_ordered"
    t.check_constraint "quantity_received >= 0", name: "chk_purchase_order_lines_quantity_received"
    t.check_constraint "supplier_discount_bps IS NULL OR supplier_discount_bps >= 0 AND supplier_discount_bps <= 10000", name: "chk_purchase_order_lines_supplier_discount_bps"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.datetime "submitted_at"
    t.bigint "submitted_by_user_id"
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.index ["store_id", "status"], name: "index_purchase_orders_on_store_id_and_status"
    t.index ["store_id"], name: "index_purchase_orders_on_store_id"
    t.index ["submitted_by_user_id"], name: "index_purchase_orders_on_submitted_by_user_id"
    t.index ["vendor_id", "status"], name: "index_purchase_orders_on_vendor_id_and_status"
    t.index ["vendor_id"], name: "index_purchase_orders_on_vendor_id"
  end

  create_table "purchase_request_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "line_number", null: false
    t.bigint "product_variant_id", null: false
    t.bigint "purchase_request_id", null: false
    t.string "request_reason"
    t.integer "requested_quantity", null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["product_variant_id"], name: "index_purchase_request_lines_on_product_variant_id"
    t.index ["purchase_request_id", "line_number"], name: "idx_purchase_request_lines_request_line_number", unique: true
    t.index ["purchase_request_id"], name: "index_purchase_request_lines_on_purchase_request_id"
    t.check_constraint "requested_quantity > 0", name: "chk_purchase_request_lines_requested_quantity"
  end

  create_table "purchase_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.string "status", default: "open", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "status"], name: "index_purchase_requests_on_store_id_and_status"
    t.index ["store_id"], name: "index_purchase_requests_on_store_id"
  end

  create_table "receipt_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "line_number", null: false
    t.bigint "product_variant_id", null: false
    t.bigint "purchase_order_line_id"
    t.integer "quantity_accepted", default: 0, null: false
    t.integer "quantity_expected", default: 0, null: false
    t.integer "quantity_received", default: 0, null: false
    t.integer "quantity_rejected", default: 0, null: false
    t.bigint "receipt_id", null: false
    t.integer "supplier_discount_bps"
    t.integer "unit_cost_cents"
    t.integer "unit_list_price_cents"
    t.datetime "updated_at", null: false
    t.index ["product_variant_id"], name: "index_receipt_lines_on_product_variant_id"
    t.index ["purchase_order_line_id"], name: "index_receipt_lines_on_purchase_order_line_id"
    t.index ["receipt_id", "line_number"], name: "idx_receipt_lines_receipt_line_number", unique: true
    t.index ["receipt_id"], name: "index_receipt_lines_on_receipt_id"
    t.check_constraint "quantity_accepted >= 0", name: "chk_receipt_lines_quantity_accepted"
    t.check_constraint "quantity_expected >= 0", name: "chk_receipt_lines_quantity_expected"
    t.check_constraint "quantity_received >= 0", name: "chk_receipt_lines_quantity_received"
    t.check_constraint "quantity_rejected >= 0", name: "chk_receipt_lines_quantity_rejected"
    t.check_constraint "supplier_discount_bps IS NULL OR supplier_discount_bps >= 0 AND supplier_discount_bps <= 10000", name: "chk_receipt_lines_supplier_discount_bps"
  end

  create_table "receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inventory_posting_id"
    t.datetime "posted_at"
    t.bigint "posted_by_user_id"
    t.bigint "purchase_order_id"
    t.string "receipt_type", null: false
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.index ["inventory_posting_id"], name: "index_receipts_on_inventory_posting_id"
    t.index ["posted_by_user_id"], name: "index_receipts_on_posted_by_user_id"
    t.index ["purchase_order_id"], name: "index_receipts_on_purchase_order_id"
    t.index ["receipt_type"], name: "index_receipts_on_receipt_type"
    t.index ["store_id", "status"], name: "index_receipts_on_store_id_and_status"
    t.index ["store_id"], name: "index_receipts_on_store_id"
    t.index ["vendor_id"], name: "index_receipts_on_vendor_id"
  end

  create_table "receiving_discrepancies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "discrepancy_type", null: false
    t.text "notes"
    t.integer "quantity_delta", null: false
    t.bigint "receipt_line_id", null: false
    t.datetime "updated_at", null: false
    t.index ["receipt_line_id"], name: "index_receiving_discrepancies_on_receipt_line_id"
  end

  create_table "return_to_vendor_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "credit_amount_cents"
    t.integer "line_number", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity", null: false
    t.bigint "return_to_vendor_id", null: false
    t.integer "supplier_discount_bps"
    t.integer "unit_cost_cents"
    t.integer "unit_list_price_cents"
    t.datetime "updated_at", null: false
    t.index ["product_variant_id"], name: "index_return_to_vendor_lines_on_product_variant_id"
    t.index ["return_to_vendor_id", "line_number"], name: "idx_return_to_vendor_lines_rtv_line_number", unique: true
    t.index ["return_to_vendor_id"], name: "index_return_to_vendor_lines_on_return_to_vendor_id"
    t.check_constraint "quantity > 0", name: "chk_return_to_vendor_lines_quantity"
    t.check_constraint "supplier_discount_bps IS NULL OR supplier_discount_bps >= 0 AND supplier_discount_bps <= 10000", name: "chk_return_to_vendor_lines_supplier_discount_bps"
  end

  create_table "returns_to_vendor", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inventory_posting_id"
    t.text "notes"
    t.datetime "posted_at"
    t.bigint "posted_by_user_id"
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.index ["inventory_posting_id"], name: "index_returns_to_vendor_on_inventory_posting_id"
    t.index ["posted_by_user_id"], name: "index_returns_to_vendor_on_posted_by_user_id"
    t.index ["store_id", "status"], name: "index_returns_to_vendor_on_store_id_and_status"
    t.index ["store_id"], name: "index_returns_to_vendor_on_store_id"
    t.index ["vendor_id"], name: "index_returns_to_vendor_on_vendor_id"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "role_key", null: false
    t.boolean "system_role", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_roles_on_active"
    t.index ["name"], name: "index_roles_on_name"
    t.index ["role_key"], name: "index_roles_on_role_key", unique: true
    t.index ["system_role"], name: "index_roles_on_system_role"
  end

  create_table "store_display_locations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "display_location_id", null: false
    t.integer "linear_feet", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_store_display_locations_on_active"
    t.index ["display_location_id"], name: "index_store_display_locations_on_display_location_id"
    t.index ["store_id", "display_location_id"], name: "index_store_display_locations_unique", unique: true
    t.index ["store_id"], name: "index_store_display_locations_on_store_id"
  end

  create_table "store_tax_category_rates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.date "effective_on", null: false
    t.date "ends_on"
    t.bigint "store_id", null: false
    t.bigint "store_tax_rate_id", null: false
    t.bigint "tax_category_id", null: false
    t.datetime "updated_at", null: false
    t.index ["effective_on", "ends_on"], name: "index_store_tax_category_rates_on_effective_on_and_ends_on"
    t.index ["store_id", "tax_category_id", "active"], name: "idx_store_tax_cat_rates_store_tax_cat_active"
    t.index ["store_id", "tax_category_id", "effective_on"], name: "idx_store_tax_cat_rates_store_tax_cat_effective", unique: true
    t.index ["store_id"], name: "index_store_tax_category_rates_on_store_id"
    t.index ["store_tax_rate_id"], name: "index_store_tax_category_rates_on_store_tax_rate_id"
    t.index ["tax_category_id"], name: "index_store_tax_category_rates_on_tax_category_id"
  end

  create_table "store_tax_rates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "short_name", limit: 20, null: false
    t.bigint "store_id", null: false
    t.string "tax_identifier", limit: 1, null: false
    t.integer "tax_rate_bps", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_store_tax_rates_on_active"
    t.index ["store_id", "name"], name: "index_store_tax_rates_on_store_id_and_name", unique: true
    t.index ["store_id", "short_name"], name: "index_store_tax_rates_on_store_id_and_short_name", unique: true
    t.index ["store_id", "tax_identifier"], name: "index_store_tax_rates_on_store_id_and_tax_identifier", unique: true
    t.index ["store_id"], name: "index_store_tax_rates_on_store_id"
  end

  create_table "stores", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "country_code", limit: 2, default: "US", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "fax", limit: 20
    t.string "name", limit: 80, null: false
    t.string "phone", limit: 20
    t.string "postal_code", limit: 20
    t.string "region_code", limit: 2
    t.string "shopping_center"
    t.string "store_group", limit: 5
    t.string "store_number", limit: 4, null: false
    t.string "time_zone", default: "America/New_York", null: false
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["active"], name: "index_stores_on_active"
    t.index ["country_code", "region_code"], name: "index_stores_on_country_code_and_region_code"
    t.index ["name"], name: "index_stores_on_name"
    t.index ["store_group"], name: "index_stores_on_store_group"
    t.index ["store_number"], name: "index_stores_on_store_number", unique: true
  end

  create_table "sub_departments", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "buyback_allowed", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "default_margin_target_bps"
    t.string "default_pricing_model"
    t.bigint "default_tax_category_id", null: false
    t.bigint "department_id", null: false
    t.string "name", null: false
    t.string "short_name", null: false
    t.string "sub_department_key", null: false
    t.datetime "updated_at", null: false
    t.boolean "vendor_returnable_default", default: false, null: false
    t.index ["default_tax_category_id"], name: "index_sub_departments_on_default_tax_category_id"
    t.index ["department_id"], name: "index_sub_departments_on_department_id"
    t.index ["name"], name: "index_sub_departments_on_name", unique: true
    t.index ["short_name"], name: "index_sub_departments_on_short_name"
    t.index ["sub_department_key"], name: "index_sub_departments_on_sub_department_key", unique: true
    t.check_constraint "default_margin_target_bps IS NULL OR default_margin_target_bps >= 0 AND default_margin_target_bps <= 10000", name: "chk_sub_departments_default_margin_target_bps"
  end

  create_table "tax_categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "short_name", limit: 20, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_tax_categories_on_active"
    t.index ["name"], name: "index_tax_categories_on_name", unique: true
    t.index ["short_name"], name: "index_tax_categories_on_short_name", unique: true
    t.index ["sort_order"], name: "index_tax_categories_on_sort_order"
  end

  create_table "user_role_assignments", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "assigned_at"
    t.bigint "assigned_by_user_id"
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.string "scope_type", default: "store", null: false
    t.bigint "store_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["active"], name: "index_user_role_assignments_on_active"
    t.index ["assigned_by_user_id"], name: "index_user_role_assignments_on_assigned_by_user_id"
    t.index ["role_id"], name: "index_user_role_assignments_on_role_id"
    t.index ["scope_type"], name: "index_user_role_assignments_on_scope_type"
    t.index ["store_id"], name: "index_user_role_assignments_on_store_id"
    t.index ["user_id", "role_id", "store_id"], name: "index_user_role_assignments_unique_store", unique: true, where: "(((scope_type)::text = 'store'::text) AND (active = true))"
    t.index ["user_id", "role_id"], name: "index_user_role_assignments_unique_global", unique: true, where: "(((scope_type)::text = 'global'::text) AND (active = true))"
    t.index ["user_id"], name: "index_user_role_assignments_on_user_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.bigint "ended_by_user_id"
    t.string "ip_address"
    t.datetime "last_activity_at", null: false
    t.datetime "locked_at"
    t.string "session_token_digest", null: false
    t.string "status", default: "active", null: false
    t.bigint "store_id"
    t.datetime "unlocked_at"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.bigint "user_id", null: false
    t.bigint "workstation_id"
    t.index ["ended_at"], name: "index_user_sessions_on_ended_at"
    t.index ["ended_by_user_id"], name: "index_user_sessions_on_ended_by_user_id"
    t.index ["last_activity_at"], name: "index_user_sessions_on_last_activity_at"
    t.index ["locked_at"], name: "index_user_sessions_on_locked_at"
    t.index ["session_token_digest"], name: "index_user_sessions_on_session_token_digest", unique: true
    t.index ["status"], name: "index_user_sessions_on_status"
    t.index ["store_id"], name: "index_user_sessions_on_store_id"
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
    t.index ["workstation_id"], name: "index_user_sessions_on_workstation_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "clerk_number", limit: 10
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.bigint "default_store_id"
    t.string "display_name", limit: 80, null: false
    t.string "first_name", limit: 50, null: false
    t.boolean "force_password_change", default: false, null: false
    t.boolean "interactive_login_enabled", default: true, null: false
    t.integer "invalid_login_attempts", default: 0, null: false
    t.datetime "last_login_at"
    t.string "last_name", limit: 50, null: false
    t.datetime "locked_at"
    t.datetime "password_changed_at"
    t.string "password_digest"
    t.datetime "pin_changed_at"
    t.string "pin_digest"
    t.datetime "previous_login_at"
    t.datetime "updated_at", null: false
    t.string "user_type", default: "user", null: false
    t.string "username", limit: 50, null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["clerk_number"], name: "index_users_on_clerk_number", unique: true, where: "(clerk_number IS NOT NULL)"
    t.index ["default_store_id"], name: "index_users_on_default_store_id"
    t.index ["locked_at"], name: "index_users_on_locked_at"
    t.index ["user_type"], name: "index_users_on_user_type"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "vendor_terms", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "net_days"
    t.jsonb "terms_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.index ["active"], name: "index_vendor_terms_on_active"
    t.index ["vendor_id", "name"], name: "index_vendor_terms_on_vendor_id_and_name", unique: true
    t.index ["vendor_id"], name: "index_vendor_terms_on_vendor_id"
  end

  create_table "vendors", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "default_supplier_discount_bps"
    t.string "name", null: false
    t.bigint "parent_vendor_id"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_vendors_on_active"
    t.index ["name"], name: "index_vendors_on_name"
    t.index ["parent_vendor_id"], name: "index_vendors_on_parent_vendor_id"
  end

  create_table "workstation_assignments", force: :cascade do |t|
    t.datetime "assigned_at", null: false
    t.bigint "assigned_by_user_id"
    t.string "assignment_token_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "last_seen_at"
    t.datetime "revoked_at"
    t.datetime "updated_at", null: false
    t.bigint "workstation_id", null: false
    t.index ["assigned_by_user_id"], name: "index_workstation_assignments_on_assigned_by_user_id"
    t.index ["assignment_token_digest"], name: "index_workstation_assignments_on_assignment_token_digest", unique: true
    t.index ["last_seen_at"], name: "index_workstation_assignments_on_last_seen_at"
    t.index ["revoked_at"], name: "index_workstation_assignments_on_revoked_at"
    t.index ["workstation_id"], name: "index_workstation_assignments_on_workstation_id"
    t.index ["workstation_id"], name: "index_workstation_assignments_one_active_per_workstation", unique: true, where: "(revoked_at IS NULL)"
  end

  create_table "workstations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.string "workstation_code", null: false
    t.string "workstation_number", limit: 3, null: false
    t.string "workstation_type", null: false
    t.index ["active"], name: "index_workstations_on_active"
    t.index ["store_id", "workstation_code"], name: "index_workstations_on_store_id_and_workstation_code", unique: true
    t.index ["store_id", "workstation_number"], name: "index_workstations_on_store_id_and_workstation_number", unique: true
    t.index ["store_id"], name: "index_workstations_on_store_id"
    t.index ["workstation_type"], name: "index_workstations_on_workstation_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_events", "stores"
  add_foreign_key "audit_events", "user_sessions"
  add_foreign_key "audit_events", "users", column: "actor_user_id"
  add_foreign_key "audit_events", "workstations"
  add_foreign_key "catalog_item_identifiers", "catalog_items"
  add_foreign_key "catalog_items", "category_nodes", column: "store_category_id"
  add_foreign_key "catalog_items", "formats"
  add_foreign_key "categorizations", "category_nodes"
  add_foreign_key "category_nodes", "category_nodes", column: "parent_id"
  add_foreign_key "category_nodes", "category_schemes"
  add_foreign_key "category_nodes", "display_locations", column: "default_display_location_id"
  add_foreign_key "category_nodes", "sub_departments", column: "default_sub_department_id"
  add_foreign_key "display_locations", "display_locations", column: "parent_id"
  add_foreign_key "inventory_adjustment_lines", "inventory_adjustments"
  add_foreign_key "inventory_adjustment_lines", "inventory_locations"
  add_foreign_key "inventory_adjustment_lines", "inventory_reason_codes"
  add_foreign_key "inventory_adjustment_lines", "product_variants"
  add_foreign_key "inventory_adjustments", "inventory_postings"
  add_foreign_key "inventory_adjustments", "stores"
  add_foreign_key "inventory_adjustments", "users", column: "posted_by_user_id"
  add_foreign_key "inventory_balances", "inventory_postings", column: "last_posting_id"
  add_foreign_key "inventory_balances", "product_variants"
  add_foreign_key "inventory_balances", "stores"
  add_foreign_key "inventory_ledger_entries", "inventory_locations"
  add_foreign_key "inventory_ledger_entries", "inventory_postings"
  add_foreign_key "inventory_ledger_entries", "inventory_reason_codes"
  add_foreign_key "inventory_ledger_entries", "product_variants"
  add_foreign_key "inventory_ledger_entries", "stores"
  add_foreign_key "inventory_locations", "stores"
  add_foreign_key "inventory_postings", "inventory_postings", column: "reversal_of_posting_id"
  add_foreign_key "inventory_postings", "inventory_postings", column: "reversed_by_posting_id"
  add_foreign_key "inventory_postings", "stores"
  add_foreign_key "inventory_postings", "users", column: "posted_by_user_id"
  add_foreign_key "inventory_postings", "workstations"
  add_foreign_key "product_variant_vendors", "product_variants"
  add_foreign_key "product_variant_vendors", "vendors"
  add_foreign_key "product_variants", "display_locations"
  add_foreign_key "product_variants", "product_conditions", column: "condition_id"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_variants", "sub_departments"
  add_foreign_key "product_vendors", "products"
  add_foreign_key "product_vendors", "vendors"
  add_foreign_key "products", "catalog_items"
  add_foreign_key "products", "display_locations", column: "default_display_location_id"
  add_foreign_key "products", "sub_departments", column: "default_sub_department_id"
  add_foreign_key "purchase_order_lines", "product_variant_vendors"
  add_foreign_key "purchase_order_lines", "product_variants"
  add_foreign_key "purchase_order_lines", "purchase_orders"
  add_foreign_key "purchase_order_lines", "vendors"
  add_foreign_key "purchase_orders", "stores"
  add_foreign_key "purchase_orders", "users", column: "submitted_by_user_id"
  add_foreign_key "purchase_orders", "vendors"
  add_foreign_key "purchase_request_lines", "product_variants"
  add_foreign_key "purchase_request_lines", "purchase_requests"
  add_foreign_key "purchase_requests", "stores"
  add_foreign_key "receipt_lines", "product_variants"
  add_foreign_key "receipt_lines", "purchase_order_lines"
  add_foreign_key "receipt_lines", "receipts"
  add_foreign_key "receipts", "inventory_postings"
  add_foreign_key "receipts", "purchase_orders"
  add_foreign_key "receipts", "stores"
  add_foreign_key "receipts", "users", column: "posted_by_user_id"
  add_foreign_key "receipts", "vendors"
  add_foreign_key "receiving_discrepancies", "receipt_lines"
  add_foreign_key "return_to_vendor_lines", "product_variants"
  add_foreign_key "return_to_vendor_lines", "returns_to_vendor", column: "return_to_vendor_id"
  add_foreign_key "returns_to_vendor", "inventory_postings"
  add_foreign_key "returns_to_vendor", "stores"
  add_foreign_key "returns_to_vendor", "users", column: "posted_by_user_id"
  add_foreign_key "returns_to_vendor", "vendors"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "store_display_locations", "display_locations"
  add_foreign_key "store_display_locations", "stores"
  add_foreign_key "store_tax_category_rates", "store_tax_rates"
  add_foreign_key "store_tax_category_rates", "stores"
  add_foreign_key "store_tax_category_rates", "tax_categories"
  add_foreign_key "store_tax_rates", "stores"
  add_foreign_key "sub_departments", "departments"
  add_foreign_key "sub_departments", "tax_categories", column: "default_tax_category_id"
  add_foreign_key "user_role_assignments", "roles"
  add_foreign_key "user_role_assignments", "stores"
  add_foreign_key "user_role_assignments", "users"
  add_foreign_key "user_role_assignments", "users", column: "assigned_by_user_id"
  add_foreign_key "user_sessions", "stores"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "user_sessions", "users", column: "ended_by_user_id"
  add_foreign_key "user_sessions", "workstations"
  add_foreign_key "users", "stores", column: "default_store_id"
  add_foreign_key "vendor_terms", "vendors"
  add_foreign_key "vendors", "vendors", column: "parent_vendor_id"
  add_foreign_key "workstation_assignments", "users", column: "assigned_by_user_id"
  add_foreign_key "workstation_assignments", "workstations"
  add_foreign_key "workstations", "stores"
end
