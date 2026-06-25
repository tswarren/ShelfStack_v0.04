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
  enable_extension "pg_trgm"

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

  create_table "buyback_lines", force: :cascade do |t|
    t.integer "accepted_offer_cents"
    t.integer "accepted_resale_price_cents"
    t.integer "base_price_cents"
    t.string "base_price_source"
    t.bigint "buyback_pricing_rule_id"
    t.bigint "buyback_reject_reason_id"
    t.bigint "buyback_session_id", null: false
    t.boolean "cash_offer_overridden", default: false, null: false
    t.text "cash_offer_override_reason"
    t.bigint "catalog_item_id"
    t.string "condition_snapshot"
    t.datetime "created_at", null: false
    t.bigint "created_catalog_item_id"
    t.bigint "created_product_id"
    t.bigint "created_product_variant_id"
    t.string "creator_snapshot"
    t.integer "current_selling_price_cents"
    t.datetime "customer_decision_at"
    t.string "format_snapshot"
    t.boolean "hold_for_review", default: false, null: false
    t.string "identifier_entered"
    t.string "identifier_normalized"
    t.bigint "inventory_ledger_entry_id"
    t.integer "line_number", null: false
    t.integer "list_price_cents"
    t.boolean "needs_cleaning", default: false, null: false
    t.boolean "needs_label", default: true, null: false
    t.boolean "needs_review", default: false, null: false
    t.text "notes"
    t.boolean "offer_overridden", default: false, null: false
    t.string "outcome"
    t.text "override_reason"
    t.bigint "product_condition_id"
    t.bigint "product_id"
    t.bigint "product_variant_id"
    t.integer "proposed_cash_offer_cents"
    t.integer "proposed_resale_price_cents"
    t.integer "proposed_trade_credit_offer_cents"
    t.integer "quantity", default: 1, null: false
    t.boolean "resale_price_overridden", default: false, null: false
    t.text "resale_price_override_reason"
    t.boolean "signed_copy", default: false, null: false
    t.text "special_notes"
    t.string "status", default: "pending", null: false
    t.bigint "sub_department_id"
    t.integer "suggested_cash_offer_cents"
    t.integer "suggested_resale_price_cents"
    t.integer "suggested_trade_credit_offer_cents"
    t.string "title_snapshot"
    t.boolean "trade_credit_offer_overridden", default: false, null: false
    t.text "trade_credit_offer_override_reason"
    t.datetime "updated_at", null: false
    t.string "variant_sku_snapshot"
    t.bigint "void_inventory_ledger_entry_id"
    t.index ["buyback_pricing_rule_id"], name: "index_buyback_lines_on_buyback_pricing_rule_id"
    t.index ["buyback_reject_reason_id"], name: "index_buyback_lines_on_buyback_reject_reason_id"
    t.index ["buyback_session_id", "line_number"], name: "index_buyback_lines_on_buyback_session_id_and_line_number", unique: true
    t.index ["buyback_session_id"], name: "index_buyback_lines_on_buyback_session_id"
    t.index ["catalog_item_id"], name: "index_buyback_lines_on_catalog_item_id"
    t.index ["created_catalog_item_id"], name: "index_buyback_lines_on_created_catalog_item_id"
    t.index ["created_product_id"], name: "index_buyback_lines_on_created_product_id"
    t.index ["created_product_variant_id"], name: "index_buyback_lines_on_created_product_variant_id"
    t.index ["inventory_ledger_entry_id"], name: "index_buyback_lines_on_inventory_ledger_entry_id"
    t.index ["product_condition_id"], name: "index_buyback_lines_on_product_condition_id"
    t.index ["product_id"], name: "index_buyback_lines_on_product_id"
    t.index ["product_variant_id"], name: "index_buyback_lines_on_product_variant_id"
    t.index ["sub_department_id"], name: "index_buyback_lines_on_sub_department_id"
    t.index ["void_inventory_ledger_entry_id"], name: "index_buyback_lines_on_void_inventory_ledger_entry_id"
  end

  create_table "buyback_pricing_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "base_price_source", default: "variant_selling_price", null: false
    t.integer "cash_offer_bps", null: false
    t.datetime "created_at", null: false
    t.integer "maximum_offer_cents"
    t.integer "minimum_offer_cents", default: 0, null: false
    t.string "name", null: false
    t.bigint "product_condition_id"
    t.integer "resale_price_factor_bps"
    t.integer "rounding_increment_cents", default: 100, null: false
    t.integer "sort_order", default: 0, null: false
    t.bigint "sub_department_id"
    t.integer "trade_credit_offer_bps", null: false
    t.datetime "updated_at", null: false
    t.index ["product_condition_id"], name: "index_buyback_pricing_rules_on_product_condition_id"
    t.index ["sub_department_id"], name: "index_buyback_pricing_rules_on_sub_department_id"
  end

  create_table "buyback_reject_reasons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "reason_key", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["reason_key"], name: "index_buyback_reject_reasons_on_reason_key", unique: true
  end

  create_table "buyback_sequences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "last_sequence", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workstation_id", null: false
    t.index ["workstation_id"], name: "index_buyback_sequences_on_workstation_id", unique: true
  end

  create_table "buyback_sessions", force: :cascade do |t|
    t.integer "accepted_payout_cents", default: 0, null: false
    t.date "business_date"
    t.string "buyback_number"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_user_id"
    t.datetime "completed_at"
    t.bigint "completed_by_user_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.datetime "customer_decision_at"
    t.bigint "customer_id", null: false
    t.integer "donation_value_cents", default: 0, null: false
    t.boolean "hold_for_review", default: false, null: false
    t.bigint "inventory_posting_id"
    t.boolean "needs_cleaning", default: false, null: false
    t.boolean "needs_label", default: true, null: false
    t.boolean "needs_review", default: false, null: false
    t.text "notes"
    t.string "payout_mode"
    t.datetime "payout_selected_at"
    t.bigint "pos_cash_movement_id"
    t.bigint "pos_register_session_id"
    t.text "processing_notes"
    t.datetime "proposal_printed_at"
    t.datetime "proposal_saved_at"
    t.datetime "quoted_at"
    t.string "seller_address_line1_snapshot"
    t.string "seller_address_line2_snapshot"
    t.boolean "seller_age_confirmed", default: false, null: false
    t.string "seller_city_snapshot"
    t.string "seller_country_code_snapshot"
    t.string "seller_display_name_snapshot"
    t.string "seller_email_snapshot"
    t.string "seller_first_name_snapshot"
    t.boolean "seller_identity_verified", default: false, null: false
    t.string "seller_last_name_snapshot"
    t.string "seller_phone_snapshot"
    t.string "seller_postal_code_snapshot"
    t.string "seller_region_code_snapshot"
    t.datetime "seller_signature_captured_at"
    t.datetime "seller_terms_accepted_at"
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.bigint "stored_value_account_id"
    t.bigint "stored_value_ledger_entry_id"
    t.integer "total_cash_offer_cents", default: 0, null: false
    t.integer "total_trade_credit_offer_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.text "void_reason"
    t.datetime "voided_at"
    t.bigint "voided_by_user_id"
    t.bigint "workstation_id"
    t.index ["buyback_number"], name: "index_buyback_sessions_on_buyback_number", unique: true, where: "(buyback_number IS NOT NULL)"
    t.index ["cancelled_by_user_id"], name: "index_buyback_sessions_on_cancelled_by_user_id"
    t.index ["completed_by_user_id"], name: "index_buyback_sessions_on_completed_by_user_id"
    t.index ["created_by_user_id"], name: "index_buyback_sessions_on_created_by_user_id"
    t.index ["customer_id"], name: "index_buyback_sessions_on_customer_id"
    t.index ["inventory_posting_id"], name: "index_buyback_sessions_on_inventory_posting_id"
    t.index ["pos_cash_movement_id"], name: "index_buyback_sessions_on_pos_cash_movement_id"
    t.index ["pos_register_session_id"], name: "index_buyback_sessions_on_pos_register_session_id"
    t.index ["store_id", "status"], name: "index_buyback_sessions_on_store_id_and_status"
    t.index ["store_id"], name: "index_buyback_sessions_on_store_id"
    t.index ["stored_value_account_id"], name: "index_buyback_sessions_on_stored_value_account_id"
    t.index ["stored_value_ledger_entry_id"], name: "index_buyback_sessions_on_stored_value_ledger_entry_id"
    t.index ["voided_by_user_id"], name: "index_buyback_sessions_on_voided_by_user_id"
    t.index ["workstation_id"], name: "index_buyback_sessions_on_workstation_id"
  end

  create_table "buyback_voids", force: :cascade do |t|
    t.bigint "buyback_session_id", null: false
    t.datetime "created_at", null: false
    t.bigint "inventory_posting_id"
    t.text "notes"
    t.bigint "pos_authorization_id"
    t.bigint "pos_register_session_id"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "void_cash_movement_id"
    t.text "void_reason", null: false
    t.bigint "void_stored_value_ledger_entry_id"
    t.datetime "voided_at", null: false
    t.bigint "voided_by_user_id", null: false
    t.bigint "workstation_id", null: false
    t.index ["buyback_session_id"], name: "index_buyback_voids_on_buyback_session_id", unique: true
    t.index ["inventory_posting_id"], name: "index_buyback_voids_on_inventory_posting_id"
    t.index ["pos_authorization_id"], name: "index_buyback_voids_on_pos_authorization_id"
    t.index ["pos_register_session_id"], name: "index_buyback_voids_on_pos_register_session_id"
    t.index ["store_id"], name: "index_buyback_voids_on_store_id"
    t.index ["void_cash_movement_id"], name: "index_buyback_voids_on_void_cash_movement_id"
    t.index ["void_stored_value_ledger_entry_id"], name: "index_buyback_voids_on_void_stored_value_ledger_entry_id"
    t.index ["voided_by_user_id"], name: "index_buyback_voids_on_voided_by_user_id"
    t.index ["workstation_id"], name: "index_buyback_voids_on_workstation_id"
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
    t.bigint "created_from_buyback_session_id"
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
    t.boolean "needs_review", default: false, null: false
    t.integer "page_count"
    t.date "publication_date"
    t.string "publication_frequency"
    t.string "publication_status", default: "active", null: false
    t.string "publisher"
    t.jsonb "publisher_details"
    t.jsonb "series_data"
    t.string "series_enumeration", limit: 15
    t.string "series_name"
    t.string "source", default: "manual", null: false
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
    t.index ["created_from_buyback_session_id"], name: "index_catalog_items_on_created_from_buyback_session_id"
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

  create_table "customer_contact_events", force: :cascade do |t|
    t.string "contact_method", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.bigint "customer_request_id"
    t.bigint "customer_request_line_id"
    t.string "direction", null: false
    t.datetime "occurred_at", null: false
    t.bigint "recorded_by_user_id", null: false
    t.string "status", null: false
    t.text "summary", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_contact_events_on_customer_id"
    t.index ["customer_request_id"], name: "index_customer_contact_events_on_customer_request_id"
    t.index ["customer_request_line_id"], name: "index_customer_contact_events_on_customer_request_line_id"
    t.index ["occurred_at"], name: "index_customer_contact_events_on_occurred_at"
    t.index ["recorded_by_user_id"], name: "index_customer_contact_events_on_recorded_by_user_id"
  end

  create_table "customer_request_lines", force: :cascade do |t|
    t.integer "approved_quantity", default: 0, null: false
    t.integer "cancelled_quantity", default: 0, null: false
    t.bigint "catalog_item_id"
    t.datetime "created_at", null: false
    t.bigint "customer_request_id", null: false
    t.integer "filled_quantity", default: 0, null: false
    t.integer "line_number", null: false
    t.integer "max_customer_price_cents"
    t.text "notes"
    t.integer "ordered_quantity", default: 0, null: false
    t.bigint "product_id"
    t.bigint "product_variant_id"
    t.string "provisional_creator"
    t.string "provisional_format"
    t.string "provisional_identifier"
    t.string "provisional_title"
    t.integer "quoted_price_cents"
    t.string "request_type", null: false
    t.integer "requested_quantity", default: 1, null: false
    t.string "status", default: "new", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_item_id"], name: "index_customer_request_lines_on_catalog_item_id"
    t.index ["customer_request_id", "line_number"], name: "idx_customer_request_lines_request_line_number", unique: true
    t.index ["customer_request_id"], name: "index_customer_request_lines_on_customer_request_id"
    t.index ["product_id"], name: "index_customer_request_lines_on_product_id"
    t.index ["product_variant_id"], name: "index_customer_request_lines_on_product_variant_id"
    t.index ["status", "request_type"], name: "index_customer_request_lines_on_status_and_request_type"
    t.check_constraint "approved_quantity >= 0", name: "chk_customer_request_lines_approved_quantity"
    t.check_constraint "cancelled_quantity >= 0", name: "chk_customer_request_lines_cancelled_quantity"
    t.check_constraint "filled_quantity >= 0", name: "chk_customer_request_lines_filled_quantity"
    t.check_constraint "ordered_quantity >= 0", name: "chk_customer_request_lines_ordered_quantity"
    t.check_constraint "requested_quantity > 0", name: "chk_customer_request_lines_requested_quantity"
  end

  create_table "customer_request_sequences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "last_sequence", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id"], name: "index_customer_request_sequences_on_store_id", unique: true
  end

  create_table "customer_requests", force: :cascade do |t|
    t.bigint "assigned_to_user_id"
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.string "customer_email_snapshot"
    t.bigint "customer_id"
    t.string "customer_name_snapshot"
    t.string "customer_phone_snapshot"
    t.datetime "expires_at"
    t.datetime "last_contacted_at"
    t.date "needed_by_date"
    t.text "notes"
    t.string "preferred_contact_method"
    t.string "request_number", null: false
    t.string "source", default: "in_store", null: false
    t.string "status", default: "new", null: false
    t.bigint "store_id", null: false
    t.text "unfillable_reason"
    t.datetime "updated_at", null: false
    t.index ["assigned_to_user_id"], name: "index_customer_requests_on_assigned_to_user_id"
    t.index ["created_by_user_id"], name: "index_customer_requests_on_created_by_user_id"
    t.index ["customer_id"], name: "index_customer_requests_on_customer_id"
    t.index ["store_id", "request_number"], name: "index_customer_requests_on_store_id_and_request_number", unique: true
    t.index ["store_id", "status"], name: "index_customer_requests_on_store_id_and_status"
    t.index ["store_id"], name: "index_customer_requests_on_store_id"
  end

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "country_code", default: "US", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id"
    t.string "customer_number"
    t.date "date_of_birth"
    t.string "display_name", null: false
    t.string "email"
    t.string "email_normalized"
    t.string "first_name"
    t.bigint "home_store_id"
    t.string "last_name"
    t.bigint "merged_into_customer_id"
    t.text "notes"
    t.string "phone"
    t.string "phone_normalized"
    t.string "postal_code"
    t.string "preferred_contact_method"
    t.string "region_code"
    t.datetime "updated_at", null: false
    t.bigint "updated_by_user_id"
    t.index ["active"], name: "index_customers_on_active"
    t.index ["created_by_user_id"], name: "index_customers_on_created_by_user_id"
    t.index ["display_name"], name: "index_customers_on_display_name"
    t.index ["display_name"], name: "index_customers_on_display_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["email"], name: "index_customers_on_email_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["home_store_id"], name: "index_customers_on_home_store_id"
    t.index ["merged_into_customer_id"], name: "index_customers_on_merged_into_customer_id"
    t.index ["phone"], name: "index_customers_on_phone_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["updated_by_user_id"], name: "index_customers_on_updated_by_user_id"
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

  create_table "external_catalog_imports", force: :cascade do |t|
    t.string "action_type", null: false
    t.datetime "applied_at"
    t.bigint "catalog_item_id"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "external_data_source_id", null: false
    t.bigint "external_lookup_result_id", null: false
    t.jsonb "field_mapping_snapshot", default: {}, null: false
    t.bigint "imported_by_user_id", null: false
    t.bigint "product_id"
    t.bigint "product_variant_id"
    t.jsonb "raw_payload_json", default: {}, null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["applied_at"], name: "index_external_catalog_imports_on_applied_at"
    t.index ["catalog_item_id"], name: "index_external_catalog_imports_on_catalog_item_id"
    t.index ["external_data_source_id"], name: "index_external_catalog_imports_on_external_data_source_id"
    t.index ["external_lookup_result_id", "catalog_item_id", "action_type"], name: "index_external_catalog_imports_on_result_item_action_applied", unique: true, where: "(((status)::text = 'applied'::text) AND ((action_type)::text = ANY (ARRAY[('create_catalog_item'::character varying)::text, ('link_existing_catalog_item'::character varying)::text, ('fill_blank_existing_catalog_item'::character varying)::text])))"
    t.index ["external_lookup_result_id"], name: "index_external_catalog_imports_on_external_lookup_result_id"
    t.index ["imported_by_user_id"], name: "index_external_catalog_imports_on_imported_by_user_id"
    t.index ["product_id"], name: "index_external_catalog_imports_on_product_id"
    t.index ["product_variant_id"], name: "index_external_catalog_imports_on_product_variant_id"
  end

  create_table "external_data_sources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "base_url", null: false
    t.jsonb "configuration_json", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "last_health_check_at"
    t.string "last_health_check_status"
    t.integer "last_plan_limit_left"
    t.integer "last_plan_limit_spent"
    t.integer "last_plan_limit_total"
    t.string "name", null: false
    t.string "source_key", null: false
    t.datetime "updated_at", null: false
    t.index ["source_key"], name: "index_external_data_sources_on_source_key", unique: true
  end

  create_table "external_lookup_requests", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "error_code"
    t.text "error_message"
    t.bigint "external_data_source_id", null: false
    t.string "lookup_type", null: false
    t.string "normalized_query"
    t.string "query", null: false
    t.jsonb "request_params_json", default: {}, null: false
    t.string "request_path"
    t.bigint "requested_by_user_id", null: false
    t.integer "response_status_code"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_external_lookup_requests_on_created_at"
    t.index ["external_data_source_id", "lookup_type", "normalized_query"], name: "index_external_lookup_requests_on_source_type_query"
    t.index ["external_data_source_id"], name: "index_external_lookup_requests_on_external_data_source_id"
    t.index ["requested_by_user_id"], name: "index_external_lookup_requests_on_requested_by_user_id"
    t.index ["status"], name: "index_external_lookup_requests_on_status"
  end

  create_table "external_lookup_results", force: :cascade do |t|
    t.jsonb "authors_snapshot", default: [], null: false
    t.string "binding_snapshot"
    t.decimal "confidence_score", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3
    t.string "date_published_snapshot"
    t.string "dewey_decimal_snapshot"
    t.jsonb "dimensions_snapshot", default: {}, null: false
    t.text "excerpt"
    t.string "external_identifier"
    t.bigint "external_lookup_request_id", null: false
    t.string "image_url"
    t.string "isbn10"
    t.string "isbn13"
    t.string "language_snapshot"
    t.bigint "local_catalog_item_id"
    t.bigint "local_product_id"
    t.bigint "local_product_variant_id"
    t.integer "msrp_cents"
    t.jsonb "other_isbns_snapshot", default: [], null: false
    t.integer "pages"
    t.jsonb "publisher_snapshot", default: {}, null: false
    t.jsonb "raw_payload_json", default: {}, null: false
    t.boolean "selected", default: false, null: false
    t.string "source_key", null: false
    t.jsonb "subjects_snapshot", default: [], null: false
    t.string "subtitle"
    t.text "synopsis"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["external_lookup_request_id"], name: "index_external_lookup_results_on_external_lookup_request_id"
    t.index ["isbn10"], name: "index_external_lookup_results_on_isbn10"
    t.index ["isbn13"], name: "index_external_lookup_results_on_isbn13"
    t.index ["local_catalog_item_id"], name: "index_external_lookup_results_on_local_catalog_item_id"
    t.index ["local_product_id"], name: "index_external_lookup_results_on_local_product_id"
    t.index ["local_product_variant_id"], name: "index_external_lookup_results_on_local_product_variant_id"
    t.index ["source_key", "external_identifier"], name: "index_external_lookup_results_on_source_and_identifier"
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
    t.integer "quantity_reserved", default: 0, null: false
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
    t.check_constraint "quantity_reserved >= 0", name: "chk_inventory_balances_quantity_reserved"
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

  create_table "inventory_reservations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.bigint "customer_request_line_id"
    t.datetime "expires_at"
    t.datetime "fulfilled_at"
    t.text "notes"
    t.boolean "over_reserved", default: false, null: false
    t.datetime "override_authorized_at"
    t.bigint "override_authorized_by_user_id"
    t.text "override_reason"
    t.bigint "pos_transaction_line_id"
    t.bigint "product_variant_id", null: false
    t.bigint "purchase_order_line_id"
    t.integer "quantity_fulfilled", default: 0, null: false
    t.integer "quantity_released", default: 0, null: false
    t.integer "quantity_reserved", null: false
    t.datetime "ready_at"
    t.bigint "receipt_line_id"
    t.string "release_reason"
    t.datetime "released_at"
    t.string "reservation_type", null: false
    t.datetime "reserved_at", null: false
    t.bigint "reserved_by_user_id", null: false
    t.bigint "special_order_id"
    t.string "status", default: "active", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_inventory_reservations_on_customer_id"
    t.index ["customer_request_line_id"], name: "index_inventory_reservations_on_customer_request_line_id"
    t.index ["expires_at"], name: "index_inventory_reservations_on_expires_at"
    t.index ["override_authorized_by_user_id"], name: "index_inventory_reservations_on_override_authorized_by_user_id"
    t.index ["pos_transaction_line_id"], name: "index_inventory_reservations_on_pos_transaction_line_id"
    t.index ["product_variant_id"], name: "index_inventory_reservations_on_product_variant_id"
    t.index ["purchase_order_line_id"], name: "index_inventory_reservations_on_purchase_order_line_id"
    t.index ["receipt_line_id"], name: "index_inventory_reservations_on_receipt_line_id"
    t.index ["reserved_by_user_id"], name: "index_inventory_reservations_on_reserved_by_user_id"
    t.index ["special_order_id"], name: "index_inventory_reservations_on_special_order_id"
    t.index ["store_id", "product_variant_id", "status"], name: "idx_inventory_reservations_store_variant_status"
    t.index ["store_id", "status", "reservation_type"], name: "idx_inventory_reservations_store_status_type"
    t.index ["store_id"], name: "index_inventory_reservations_on_store_id"
    t.check_constraint "(quantity_fulfilled + quantity_released) <= quantity_reserved", name: "chk_inventory_reservations_quantity_balance"
    t.check_constraint "quantity_fulfilled >= 0", name: "chk_inventory_reservations_quantity_fulfilled"
    t.check_constraint "quantity_released >= 0", name: "chk_inventory_reservations_quantity_released"
    t.check_constraint "quantity_reserved > 0", name: "chk_inventory_reservations_quantity_reserved"
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

  create_table "pos_authorizations", force: :cascade do |t|
    t.string "authorization_type", null: false
    t.datetime "created_at", null: false
    t.datetime "denied_at"
    t.jsonb "details", default: {}, null: false
    t.datetime "granted_at"
    t.bigint "granted_by_user_id"
    t.bigint "pos_register_session_id"
    t.bigint "pos_transaction_id"
    t.bigint "requested_by_user_id", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["granted_by_user_id"], name: "index_pos_authorizations_on_granted_by_user_id"
    t.index ["pos_register_session_id"], name: "index_pos_authorizations_on_pos_register_session_id"
    t.index ["pos_transaction_id"], name: "index_pos_authorizations_on_pos_transaction_id"
    t.index ["requested_by_user_id"], name: "index_pos_authorizations_on_requested_by_user_id"
    t.index ["store_id"], name: "index_pos_authorizations_on_store_id"
  end

  create_table "pos_cash_movements", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "movement_type", null: false
    t.text "notes"
    t.bigint "pos_register_session_id", null: false
    t.string "reason_code"
    t.datetime "recorded_at", null: false
    t.bigint "recorded_by_user_id", null: false
    t.bigint "reverses_cash_movement_id"
    t.bigint "source_id"
    t.string "source_type"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pos_register_session_id"], name: "index_pos_cash_movements_on_pos_register_session_id"
    t.index ["recorded_by_user_id"], name: "index_pos_cash_movements_on_recorded_by_user_id"
    t.index ["reverses_cash_movement_id"], name: "index_pos_cash_movements_on_reverses_cash_movement_id"
    t.index ["source_type", "source_id"], name: "index_pos_cash_movements_on_source_type_and_source_id"
    t.index ["store_id"], name: "index_pos_cash_movements_on_store_id"
  end

  create_table "pos_receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "issued_at", null: false
    t.bigint "pos_transaction_id", null: false
    t.string "receipt_number", null: false
    t.integer "reprint_count", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pos_transaction_id"], name: "index_pos_receipts_on_pos_transaction_id", unique: true
    t.index ["receipt_number"], name: "index_pos_receipts_on_receipt_number", unique: true
    t.index ["store_id"], name: "index_pos_receipts_on_store_id"
  end

  create_table "pos_register_sessions", force: :cascade do |t|
    t.date "business_date", null: false
    t.datetime "closed_at"
    t.bigint "closed_by_user_id"
    t.integer "counted_closing_cash_cents"
    t.datetime "created_at", null: false
    t.integer "expected_closing_cash_cents"
    t.boolean "force_closed", default: false, null: false
    t.text "notes"
    t.datetime "opened_at", null: false
    t.bigint "opened_by_user_id", null: false
    t.integer "opening_cash_cents", default: 0, null: false
    t.string "status", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "workstation_id", null: false
    t.index ["closed_by_user_id"], name: "index_pos_register_sessions_on_closed_by_user_id"
    t.index ["opened_by_user_id"], name: "index_pos_register_sessions_on_opened_by_user_id"
    t.index ["store_id", "business_date"], name: "index_pos_register_sessions_on_store_id_and_business_date"
    t.index ["store_id"], name: "index_pos_register_sessions_on_store_id"
    t.index ["workstation_id", "opened_at"], name: "index_pos_register_sessions_on_workstation_id_and_opened_at"
    t.index ["workstation_id"], name: "index_pos_register_sessions_on_workstation_id"
    t.index ["workstation_id"], name: "index_pos_register_sessions_one_open_per_workstation", unique: true, where: "((status)::text = 'open'::text)"
  end

  create_table "pos_tenders", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.string "card_authorization_code"
    t.string "card_brand"
    t.string "card_last_four"
    t.integer "change_cents"
    t.string "check_number"
    t.datetime "created_at", null: false
    t.boolean "generate_stored_value_identifier", default: false, null: false
    t.integer "line_number", null: false
    t.text "notes"
    t.bigint "pos_transaction_id", null: false
    t.string "reference_number"
    t.bigint "reverses_tender_id"
    t.bigint "stored_value_account_id"
    t.bigint "stored_value_identifier_id"
    t.string "tender_type", null: false
    t.integer "tendered_cents"
    t.datetime "updated_at", null: false
    t.index ["pos_transaction_id", "line_number"], name: "index_pos_tenders_on_pos_transaction_id_and_line_number", unique: true
    t.index ["pos_transaction_id"], name: "index_pos_tenders_on_pos_transaction_id"
    t.index ["reverses_tender_id"], name: "index_pos_tenders_on_reverses_tender_id"
    t.index ["stored_value_account_id"], name: "index_pos_tenders_on_stored_value_account_id"
    t.index ["stored_value_identifier_id"], name: "index_pos_tenders_on_stored_value_identifier_id"
  end

  create_table "pos_transaction_lines", force: :cascade do |t|
    t.boolean "cogs_estimated", default: false, null: false
    t.string "cogs_source"
    t.string "costing_method_snapshot"
    t.datetime "created_at", null: false
    t.bigint "customer_request_line_id"
    t.integer "extended_price_cents", default: 0, null: false
    t.boolean "generate_stored_value_identifier", default: false, null: false
    t.string "inventory_behavior_snapshot"
    t.bigint "inventory_reservation_id"
    t.string "inventory_tracking_snapshot"
    t.integer "line_discount_cents", default: 0, null: false
    t.integer "line_number", null: false
    t.string "line_type", null: false
    t.string "open_ring_description"
    t.bigint "pos_transaction_id", null: false
    t.bigint "product_id"
    t.string "product_name_snapshot"
    t.string "product_sku_snapshot"
    t.bigint "product_variant_id"
    t.integer "quantity", null: false
    t.string "return_disposition"
    t.string "revenue_treatment"
    t.integer "source_sold_quantity_snapshot"
    t.bigint "source_transaction_id"
    t.bigint "source_transaction_line_id"
    t.bigint "special_order_id"
    t.bigint "store_tax_rate_id"
    t.string "store_tax_rate_short_name_snapshot"
    t.bigint "stored_value_account_id"
    t.bigint "stored_value_identifier_id"
    t.bigint "sub_department_id"
    t.string "sub_department_name_snapshot"
    t.bigint "tax_category_id"
    t.integer "tax_cents", default: 0, null: false
    t.string "tax_identifier_snapshot", limit: 1
    t.integer "tax_rate_bps"
    t.integer "total_cogs_cents"
    t.integer "transaction_discount_cents", default: 0, null: false
    t.integer "unit_cogs_cents"
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.string "variant_name_snapshot"
    t.string "variant_sku_snapshot"
    t.index ["customer_request_line_id"], name: "index_pos_transaction_lines_on_customer_request_line_id"
    t.index ["inventory_reservation_id"], name: "index_pos_transaction_lines_on_inventory_reservation_id"
    t.index ["pos_transaction_id", "line_number"], name: "index_pos_transaction_lines_on_transaction_and_line_number", unique: true
    t.index ["pos_transaction_id"], name: "index_pos_transaction_lines_on_pos_transaction_id"
    t.index ["product_id"], name: "index_pos_transaction_lines_on_product_id"
    t.index ["product_variant_id"], name: "index_pos_transaction_lines_on_product_variant_id"
    t.index ["source_transaction_id"], name: "index_pos_transaction_lines_on_source_transaction_id"
    t.index ["source_transaction_line_id"], name: "index_pos_transaction_lines_on_source_transaction_line_id"
    t.index ["special_order_id"], name: "index_pos_transaction_lines_on_special_order_id"
    t.index ["store_tax_rate_id"], name: "index_pos_transaction_lines_on_store_tax_rate_id"
    t.index ["stored_value_account_id"], name: "index_pos_transaction_lines_on_stored_value_account_id"
    t.index ["stored_value_identifier_id"], name: "index_pos_transaction_lines_on_stored_value_identifier_id"
    t.index ["sub_department_id"], name: "index_pos_transaction_lines_on_sub_department_id"
    t.index ["tax_category_id"], name: "index_pos_transaction_lines_on_tax_category_id"
    t.check_constraint "cogs_source IS NULL OR (cogs_source::text = ANY (ARRAY['moving_average'::character varying, 'unit_cost'::character varying, 'receipt_cost'::character varying, 'buyback_offer'::character varying, 'margin_estimate'::character varying, 'return_reversal'::character varying, 'none'::character varying, 'unknown'::character varying]::text[]))", name: "pos_transaction_lines_cogs_source_chk"
    t.check_constraint "costing_method_snapshot IS NULL OR (costing_method_snapshot::text = ANY (ARRAY['moving_average'::character varying, 'unit_cost'::character varying, 'receipt_cost'::character varying, 'buyback_offer'::character varying, 'margin_estimate'::character varying, 'return_reversal'::character varying, 'none'::character varying, 'unknown'::character varying]::text[]))", name: "pos_transaction_lines_costing_method_snapshot_chk"
    t.check_constraint "inventory_tracking_snapshot IS NULL OR (inventory_tracking_snapshot::text = ANY (ARRAY['inventory'::character varying, 'non_inventory'::character varying]::text[]))", name: "pos_transaction_lines_inventory_tracking_snapshot_chk"
    t.check_constraint "revenue_treatment IS NULL OR (revenue_treatment::text = ANY (ARRAY['merchandise'::character varying, 'service'::character varying, 'liability'::character varying, 'passthrough'::character varying, 'none'::character varying]::text[]))", name: "pos_transaction_lines_revenue_treatment_chk"
    t.check_constraint "unit_cogs_cents IS NULL OR unit_cogs_cents >= 0", name: "pos_transaction_lines_unit_cogs_cents_chk"
  end

  create_table "pos_transactions", force: :cascade do |t|
    t.date "business_date"
    t.bigint "cashier_user_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.integer "discount_cents", default: 0, null: false
    t.text "notes"
    t.bigint "pos_register_session_id"
    t.integer "rounding_cents", default: 0, null: false
    t.string "status", null: false
    t.bigint "store_id", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.datetime "suspended_at"
    t.integer "tax_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.string "transaction_number"
    t.string "transaction_type"
    t.datetime "updated_at", null: false
    t.bigint "user_session_id"
    t.datetime "voided_at"
    t.bigint "workstation_id", null: false
    t.index ["cashier_user_id"], name: "index_pos_transactions_on_cashier_user_id"
    t.index ["customer_id"], name: "index_pos_transactions_on_customer_id"
    t.index ["pos_register_session_id"], name: "index_pos_transactions_on_pos_register_session_id"
    t.index ["store_id", "business_date", "status"], name: "idx_on_store_id_business_date_status_0fa1c34368"
    t.index ["store_id", "completed_at"], name: "index_pos_transactions_on_store_id_and_completed_at"
    t.index ["store_id"], name: "index_pos_transactions_on_store_id"
    t.index ["transaction_number"], name: "index_pos_transactions_on_transaction_number", unique: true, where: "(transaction_number IS NOT NULL)"
    t.index ["user_session_id"], name: "index_pos_transactions_on_user_session_id"
    t.index ["workstation_id", "transaction_number"], name: "index_pos_transactions_on_workstation_and_number", unique: true, where: "(transaction_number IS NOT NULL)"
    t.index ["workstation_id"], name: "index_pos_transactions_on_workstation_id"
  end

  create_table "pos_voids", force: :cascade do |t|
    t.date "business_date", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "pos_authorization_id"
    t.bigint "pos_register_session_id", null: false
    t.bigint "pos_transaction_id", null: false
    t.string "reason_code"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "voided_at", null: false
    t.bigint "voided_by_user_id", null: false
    t.bigint "workstation_id", null: false
    t.index ["pos_authorization_id"], name: "index_pos_voids_on_pos_authorization_id"
    t.index ["pos_register_session_id"], name: "index_pos_voids_on_pos_register_session_id"
    t.index ["pos_transaction_id"], name: "index_pos_voids_on_pos_transaction_id", unique: true
    t.index ["store_id"], name: "index_pos_voids_on_store_id"
    t.index ["voided_by_user_id"], name: "index_pos_voids_on_voided_by_user_id"
    t.index ["workstation_id"], name: "index_pos_voids_on_workstation_id"
  end

  create_table "pos_workstation_sequences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "last_sequence", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workstation_id", null: false
    t.index ["workstation_id"], name: "index_pos_workstation_sequences_on_workstation_id", unique: true
  end

  create_table "product_conditions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "buyback_default", default: false, null: false
    t.boolean "buyback_eligible", default: false, null: false
    t.integer "buyback_price_factor_bps"
    t.boolean "buyback_requires_review", default: false, null: false
    t.integer "buyback_sort_order"
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
    t.check_constraint "returnability_status IS NULL OR (returnability_status::text = ANY (ARRAY['returnable'::character varying::text, 'non_returnable'::character varying::text, 'conditional'::character varying::text, 'unknown'::character varying::text]))", name: "chk_product_variant_vendors_returnability_status"
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
    t.bigint "created_from_buyback_session_id"
    t.bigint "display_location_id"
    t.string "inventory_behavior", default: "standard_physical", null: false
    t.string "inventory_tracking_override"
    t.string "name", null: false
    t.string "name_override"
    t.boolean "needs_review", default: false, null: false
    t.string "pricing_model_override"
    t.bigint "product_id", null: false
    t.string "returnability_status", default: "unknown", null: false
    t.integer "selling_price_cents", default: 0, null: false
    t.string "short_name", limit: 40
    t.string "sku", limit: 50, null: false
    t.string "source", default: "manual", null: false
    t.bigint "sub_department_id", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_product_variants_on_active"
    t.index ["condition_id"], name: "index_product_variants_on_condition_id"
    t.index ["created_from_buyback_session_id"], name: "index_product_variants_on_created_from_buyback_session_id"
    t.index ["display_location_id"], name: "index_product_variants_on_display_location_id"
    t.index ["inventory_behavior"], name: "index_product_variants_on_inventory_behavior"
    t.index ["pricing_model_override"], name: "index_product_variants_on_pricing_model_override"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
    t.index ["sub_department_id"], name: "index_product_variants_on_sub_department_id"
    t.check_constraint "inventory_tracking_override IS NULL OR (inventory_tracking_override::text = ANY (ARRAY['inventory'::character varying, 'non_inventory'::character varying]::text[]))", name: "product_variants_inventory_tracking_override_chk"
    t.check_constraint "returnability_status::text = ANY (ARRAY['returnable'::character varying::text, 'non_returnable'::character varying::text, 'conditional'::character varying::text, 'unknown'::character varying::text])", name: "chk_product_variants_returnability_status"
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
    t.check_constraint "returnability_status IS NULL OR (returnability_status::text = ANY (ARRAY['returnable'::character varying::text, 'non_returnable'::character varying::text, 'conditional'::character varying::text, 'unknown'::character varying::text]))", name: "chk_product_vendors_returnability_status"
    t.check_constraint "supplier_discount_bps IS NULL OR supplier_discount_bps >= 0 AND supplier_discount_bps <= 10000", name: "chk_product_vendors_supplier_discount_bps"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "catalog_item_id"
    t.datetime "created_at", null: false
    t.bigint "created_from_buyback_session_id"
    t.bigint "default_display_location_id"
    t.string "default_inventory_tracking"
    t.bigint "default_sub_department_id"
    t.integer "list_price_cents", default: 0, null: false
    t.string "name", null: false
    t.string "name_override"
    t.boolean "needs_review", default: false, null: false
    t.string "product_type", default: "physical", null: false
    t.string "short_name", limit: 40
    t.string "sku", limit: 50, null: false
    t.string "source", default: "manual", null: false
    t.datetime "updated_at", null: false
    t.string "variant1_label"
    t.string "variant2_label"
    t.string "variation_type", default: "standard", null: false
    t.index ["active"], name: "index_products_on_active"
    t.index ["catalog_item_id"], name: "index_products_on_catalog_item_id"
    t.index ["created_from_buyback_session_id"], name: "index_products_on_created_from_buyback_session_id"
    t.index ["default_display_location_id"], name: "index_products_on_default_display_location_id"
    t.index ["default_sub_department_id"], name: "index_products_on_default_sub_department_id"
    t.index ["name"], name: "index_products_on_name"
    t.index ["product_type"], name: "index_products_on_product_type"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["variation_type"], name: "index_products_on_variation_type"
    t.check_constraint "default_inventory_tracking IS NULL OR (default_inventory_tracking::text = ANY (ARRAY['inventory'::character varying, 'non_inventory'::character varying]::text[]))", name: "products_default_inventory_tracking_chk"
    t.check_constraint "list_price_cents >= 0", name: "chk_products_list_price_cents"
  end

  create_table "purchase_order_line_allocations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_request_line_id"
    t.bigint "purchase_order_line_id", null: false
    t.integer "quantity_allocated", null: false
    t.integer "quantity_received", default: 0, null: false
    t.bigint "special_order_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_request_line_id"], name: "idx_on_customer_request_line_id_c8c0d5c051"
    t.index ["purchase_order_line_id"], name: "idx_on_purchase_order_line_id_01da129fdd"
    t.index ["special_order_id"], name: "index_purchase_order_line_allocations_on_special_order_id"
    t.check_constraint "quantity_allocated > 0", name: "chk_po_line_allocations_quantity_allocated"
    t.check_constraint "quantity_received >= 0", name: "chk_po_line_allocations_quantity_received"
  end

  create_table "purchase_order_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "line_number", null: false
    t.bigint "product_variant_id", null: false
    t.bigint "product_variant_vendor_id"
    t.bigint "purchase_order_id", null: false
    t.bigint "purchase_request_line_id"
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
    t.index ["purchase_request_line_id"], name: "index_purchase_order_lines_on_purchase_request_line_id"
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

  create_table "receipt_line_allocations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_request_line_id"
    t.bigint "inventory_reservation_id"
    t.bigint "purchase_order_line_allocation_id"
    t.integer "quantity_allocated", null: false
    t.bigint "receipt_line_id", null: false
    t.bigint "special_order_id"
    t.datetime "updated_at", null: false
    t.index ["customer_request_line_id"], name: "index_receipt_line_allocations_on_customer_request_line_id"
    t.index ["inventory_reservation_id"], name: "index_receipt_line_allocations_on_inventory_reservation_id"
    t.index ["purchase_order_line_allocation_id"], name: "idx_on_purchase_order_line_allocation_id_cadeef4f00"
    t.index ["receipt_line_id"], name: "index_receipt_line_allocations_on_receipt_line_id"
    t.index ["special_order_id"], name: "index_receipt_line_allocations_on_special_order_id"
    t.check_constraint "quantity_allocated > 0", name: "chk_receipt_line_allocations_quantity_allocated"
  end

  create_table "receipt_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "exception_reason"
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "special_orders", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "cancelled_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "customer_request_line_id", null: false
    t.text "notes"
    t.datetime "ordered_at"
    t.bigint "product_variant_id"
    t.integer "quantity_cancelled", default: 0, null: false
    t.integer "quantity_committed", null: false
    t.integer "quantity_completed", default: 0, null: false
    t.integer "quantity_ordered", default: 0, null: false
    t.integer "quantity_ready", default: 0, null: false
    t.integer "quantity_received", default: 0, null: false
    t.datetime "ready_at"
    t.string "status", default: "pending_match", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_id"
    t.index ["created_by_user_id"], name: "index_special_orders_on_created_by_user_id"
    t.index ["customer_id"], name: "index_special_orders_on_customer_id"
    t.index ["customer_request_line_id"], name: "index_special_orders_on_customer_request_line_id", unique: true
    t.index ["product_variant_id"], name: "index_special_orders_on_product_variant_id"
    t.index ["store_id", "status"], name: "index_special_orders_on_store_id_and_status"
    t.index ["store_id"], name: "index_special_orders_on_store_id"
    t.index ["vendor_id"], name: "index_special_orders_on_vendor_id"
    t.check_constraint "quantity_committed > 0", name: "chk_special_orders_quantity_committed"
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

  create_table "stored_value_accounts", force: :cascade do |t|
    t.string "account_type", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "current_balance_cents", default: 0, null: false
    t.bigint "customer_id"
    t.string "holder_name_snapshot"
    t.bigint "issuing_store_id", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["account_type"], name: "index_stored_value_accounts_on_account_type"
    t.index ["customer_id"], name: "index_stored_value_accounts_on_customer_id"
    t.index ["issuing_store_id"], name: "index_stored_value_accounts_on_issuing_store_id"
  end

  create_table "stored_value_identifiers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "display_value_masked"
    t.text "encrypted_value"
    t.string "identifier_type", null: false
    t.string "lookup_digest", null: false
    t.bigint "replaced_by_identifier_id"
    t.bigint "stored_value_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["lookup_digest"], name: "index_sv_identifiers_on_active_lookup_digest", unique: true, where: "(active = true)"
    t.index ["stored_value_account_id"], name: "index_stored_value_identifiers_on_stored_value_account_id"
  end

  create_table "stored_value_ledger_entries", force: :cascade do |t|
    t.integer "amount_delta_cents", null: false
    t.integer "balance_after_cents"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.string "entry_type", null: false
    t.text "notes"
    t.datetime "posted_at", null: false
    t.bigint "reason_code_id"
    t.bigint "reverses_entry_id"
    t.bigint "source_id"
    t.string "source_type"
    t.bigint "store_id", null: false
    t.bigint "stored_value_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_stored_value_ledger_entries_on_created_by_user_id"
    t.index ["reason_code_id"], name: "index_stored_value_ledger_entries_on_reason_code_id"
    t.index ["reverses_entry_id"], name: "index_stored_value_ledger_entries_on_reverses_entry_id"
    t.index ["source_type", "source_id"], name: "index_sv_ledger_on_source"
    t.index ["store_id", "posted_at"], name: "index_sv_ledger_on_store_posted_at"
    t.index ["store_id"], name: "index_stored_value_ledger_entries_on_store_id"
    t.index ["stored_value_account_id", "posted_at"], name: "index_sv_ledger_on_account_posted_at"
    t.index ["stored_value_account_id"], name: "index_stored_value_ledger_entries_on_stored_value_account_id"
  end

  create_table "stored_value_reason_codes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "reason_key", null: false
    t.datetime "updated_at", null: false
    t.index ["reason_key"], name: "index_stored_value_reason_codes_on_reason_key", unique: true
  end

  create_table "stored_value_transfers", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "from_account_id", null: false
    t.bigint "reason_code_id", null: false
    t.bigint "to_account_id", null: false
    t.bigint "transfer_in_entry_id", null: false
    t.bigint "transfer_out_entry_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_stored_value_transfers_on_created_by_user_id"
    t.index ["from_account_id"], name: "index_stored_value_transfers_on_from_account_id"
    t.index ["reason_code_id"], name: "index_stored_value_transfers_on_reason_code_id"
    t.index ["to_account_id"], name: "index_stored_value_transfers_on_to_account_id"
    t.index ["transfer_in_entry_id"], name: "index_stored_value_transfers_on_transfer_in_entry_id"
    t.index ["transfer_out_entry_id"], name: "index_stored_value_transfers_on_transfer_out_entry_id"
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
  add_foreign_key "buyback_lines", "buyback_pricing_rules"
  add_foreign_key "buyback_lines", "buyback_reject_reasons"
  add_foreign_key "buyback_lines", "buyback_sessions"
  add_foreign_key "buyback_lines", "catalog_items"
  add_foreign_key "buyback_lines", "catalog_items", column: "created_catalog_item_id"
  add_foreign_key "buyback_lines", "inventory_ledger_entries"
  add_foreign_key "buyback_lines", "inventory_ledger_entries", column: "void_inventory_ledger_entry_id"
  add_foreign_key "buyback_lines", "product_conditions"
  add_foreign_key "buyback_lines", "product_variants"
  add_foreign_key "buyback_lines", "product_variants", column: "created_product_variant_id"
  add_foreign_key "buyback_lines", "products"
  add_foreign_key "buyback_lines", "products", column: "created_product_id"
  add_foreign_key "buyback_lines", "sub_departments"
  add_foreign_key "buyback_pricing_rules", "product_conditions"
  add_foreign_key "buyback_pricing_rules", "sub_departments"
  add_foreign_key "buyback_sequences", "workstations"
  add_foreign_key "buyback_sessions", "customers"
  add_foreign_key "buyback_sessions", "inventory_postings"
  add_foreign_key "buyback_sessions", "pos_cash_movements"
  add_foreign_key "buyback_sessions", "pos_register_sessions"
  add_foreign_key "buyback_sessions", "stored_value_accounts"
  add_foreign_key "buyback_sessions", "stored_value_ledger_entries"
  add_foreign_key "buyback_sessions", "stores"
  add_foreign_key "buyback_sessions", "users", column: "cancelled_by_user_id"
  add_foreign_key "buyback_sessions", "users", column: "completed_by_user_id"
  add_foreign_key "buyback_sessions", "users", column: "created_by_user_id"
  add_foreign_key "buyback_sessions", "users", column: "voided_by_user_id"
  add_foreign_key "buyback_sessions", "workstations"
  add_foreign_key "buyback_voids", "buyback_sessions"
  add_foreign_key "buyback_voids", "inventory_postings"
  add_foreign_key "buyback_voids", "pos_authorizations"
  add_foreign_key "buyback_voids", "pos_cash_movements", column: "void_cash_movement_id"
  add_foreign_key "buyback_voids", "pos_register_sessions"
  add_foreign_key "buyback_voids", "stored_value_ledger_entries", column: "void_stored_value_ledger_entry_id"
  add_foreign_key "buyback_voids", "stores"
  add_foreign_key "buyback_voids", "users", column: "voided_by_user_id"
  add_foreign_key "buyback_voids", "workstations"
  add_foreign_key "catalog_item_identifiers", "catalog_items"
  add_foreign_key "catalog_items", "buyback_sessions", column: "created_from_buyback_session_id"
  add_foreign_key "catalog_items", "category_nodes", column: "store_category_id"
  add_foreign_key "catalog_items", "formats"
  add_foreign_key "categorizations", "category_nodes"
  add_foreign_key "category_nodes", "category_nodes", column: "parent_id"
  add_foreign_key "category_nodes", "category_schemes"
  add_foreign_key "category_nodes", "display_locations", column: "default_display_location_id"
  add_foreign_key "category_nodes", "sub_departments", column: "default_sub_department_id"
  add_foreign_key "customer_contact_events", "customer_request_lines"
  add_foreign_key "customer_contact_events", "customer_requests"
  add_foreign_key "customer_contact_events", "customers"
  add_foreign_key "customer_contact_events", "users", column: "recorded_by_user_id"
  add_foreign_key "customer_request_lines", "catalog_items"
  add_foreign_key "customer_request_lines", "customer_requests"
  add_foreign_key "customer_request_lines", "product_variants"
  add_foreign_key "customer_request_lines", "products"
  add_foreign_key "customer_request_sequences", "stores"
  add_foreign_key "customer_requests", "customers"
  add_foreign_key "customer_requests", "stores"
  add_foreign_key "customer_requests", "users", column: "assigned_to_user_id"
  add_foreign_key "customer_requests", "users", column: "created_by_user_id"
  add_foreign_key "customers", "customers", column: "merged_into_customer_id"
  add_foreign_key "customers", "stores", column: "home_store_id"
  add_foreign_key "customers", "users", column: "created_by_user_id"
  add_foreign_key "customers", "users", column: "updated_by_user_id"
  add_foreign_key "display_locations", "display_locations", column: "parent_id"
  add_foreign_key "external_catalog_imports", "catalog_items"
  add_foreign_key "external_catalog_imports", "external_data_sources"
  add_foreign_key "external_catalog_imports", "external_lookup_results"
  add_foreign_key "external_catalog_imports", "product_variants"
  add_foreign_key "external_catalog_imports", "products"
  add_foreign_key "external_catalog_imports", "users", column: "imported_by_user_id"
  add_foreign_key "external_lookup_requests", "external_data_sources"
  add_foreign_key "external_lookup_requests", "users", column: "requested_by_user_id"
  add_foreign_key "external_lookup_results", "catalog_items", column: "local_catalog_item_id"
  add_foreign_key "external_lookup_results", "external_lookup_requests"
  add_foreign_key "external_lookup_results", "product_variants", column: "local_product_variant_id"
  add_foreign_key "external_lookup_results", "products", column: "local_product_id"
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
  add_foreign_key "inventory_reservations", "customer_request_lines"
  add_foreign_key "inventory_reservations", "customers"
  add_foreign_key "inventory_reservations", "pos_transaction_lines"
  add_foreign_key "inventory_reservations", "product_variants"
  add_foreign_key "inventory_reservations", "purchase_order_lines"
  add_foreign_key "inventory_reservations", "receipt_lines"
  add_foreign_key "inventory_reservations", "special_orders"
  add_foreign_key "inventory_reservations", "stores"
  add_foreign_key "inventory_reservations", "users", column: "override_authorized_by_user_id"
  add_foreign_key "inventory_reservations", "users", column: "reserved_by_user_id"
  add_foreign_key "pos_authorizations", "pos_register_sessions"
  add_foreign_key "pos_authorizations", "pos_transactions"
  add_foreign_key "pos_authorizations", "stores"
  add_foreign_key "pos_authorizations", "users", column: "granted_by_user_id"
  add_foreign_key "pos_authorizations", "users", column: "requested_by_user_id"
  add_foreign_key "pos_cash_movements", "pos_cash_movements", column: "reverses_cash_movement_id"
  add_foreign_key "pos_cash_movements", "pos_register_sessions"
  add_foreign_key "pos_cash_movements", "stores"
  add_foreign_key "pos_cash_movements", "users", column: "recorded_by_user_id"
  add_foreign_key "pos_receipts", "pos_transactions"
  add_foreign_key "pos_receipts", "stores"
  add_foreign_key "pos_register_sessions", "stores"
  add_foreign_key "pos_register_sessions", "users", column: "closed_by_user_id"
  add_foreign_key "pos_register_sessions", "users", column: "opened_by_user_id"
  add_foreign_key "pos_register_sessions", "workstations"
  add_foreign_key "pos_tenders", "pos_tenders", column: "reverses_tender_id"
  add_foreign_key "pos_tenders", "pos_transactions"
  add_foreign_key "pos_tenders", "stored_value_accounts"
  add_foreign_key "pos_tenders", "stored_value_identifiers"
  add_foreign_key "pos_transaction_lines", "customer_request_lines"
  add_foreign_key "pos_transaction_lines", "inventory_reservations"
  add_foreign_key "pos_transaction_lines", "pos_transaction_lines", column: "source_transaction_line_id"
  add_foreign_key "pos_transaction_lines", "pos_transactions"
  add_foreign_key "pos_transaction_lines", "pos_transactions", column: "source_transaction_id"
  add_foreign_key "pos_transaction_lines", "product_variants"
  add_foreign_key "pos_transaction_lines", "products"
  add_foreign_key "pos_transaction_lines", "special_orders"
  add_foreign_key "pos_transaction_lines", "store_tax_rates"
  add_foreign_key "pos_transaction_lines", "stored_value_accounts"
  add_foreign_key "pos_transaction_lines", "stored_value_identifiers"
  add_foreign_key "pos_transaction_lines", "sub_departments"
  add_foreign_key "pos_transaction_lines", "tax_categories"
  add_foreign_key "pos_transactions", "customers"
  add_foreign_key "pos_transactions", "pos_register_sessions"
  add_foreign_key "pos_transactions", "stores"
  add_foreign_key "pos_transactions", "user_sessions"
  add_foreign_key "pos_transactions", "users", column: "cashier_user_id"
  add_foreign_key "pos_transactions", "workstations"
  add_foreign_key "pos_voids", "pos_authorizations"
  add_foreign_key "pos_voids", "pos_register_sessions"
  add_foreign_key "pos_voids", "pos_transactions"
  add_foreign_key "pos_voids", "stores"
  add_foreign_key "pos_voids", "users", column: "voided_by_user_id"
  add_foreign_key "pos_voids", "workstations"
  add_foreign_key "pos_workstation_sequences", "workstations"
  add_foreign_key "product_variant_vendors", "product_variants"
  add_foreign_key "product_variant_vendors", "vendors"
  add_foreign_key "product_variants", "buyback_sessions", column: "created_from_buyback_session_id"
  add_foreign_key "product_variants", "display_locations"
  add_foreign_key "product_variants", "product_conditions", column: "condition_id"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_variants", "sub_departments"
  add_foreign_key "product_vendors", "products"
  add_foreign_key "product_vendors", "vendors"
  add_foreign_key "products", "buyback_sessions", column: "created_from_buyback_session_id"
  add_foreign_key "products", "catalog_items"
  add_foreign_key "products", "display_locations", column: "default_display_location_id"
  add_foreign_key "products", "sub_departments", column: "default_sub_department_id"
  add_foreign_key "purchase_order_line_allocations", "customer_request_lines"
  add_foreign_key "purchase_order_line_allocations", "purchase_order_lines"
  add_foreign_key "purchase_order_line_allocations", "special_orders"
  add_foreign_key "purchase_order_lines", "product_variant_vendors"
  add_foreign_key "purchase_order_lines", "product_variants"
  add_foreign_key "purchase_order_lines", "purchase_orders"
  add_foreign_key "purchase_order_lines", "purchase_request_lines"
  add_foreign_key "purchase_order_lines", "vendors"
  add_foreign_key "purchase_orders", "stores"
  add_foreign_key "purchase_orders", "users", column: "submitted_by_user_id"
  add_foreign_key "purchase_orders", "vendors"
  add_foreign_key "purchase_request_lines", "product_variants"
  add_foreign_key "purchase_request_lines", "purchase_requests"
  add_foreign_key "purchase_requests", "stores"
  add_foreign_key "receipt_line_allocations", "customer_request_lines"
  add_foreign_key "receipt_line_allocations", "inventory_reservations"
  add_foreign_key "receipt_line_allocations", "purchase_order_line_allocations"
  add_foreign_key "receipt_line_allocations", "receipt_lines"
  add_foreign_key "receipt_line_allocations", "special_orders"
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
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "special_orders", "customer_request_lines"
  add_foreign_key "special_orders", "customers"
  add_foreign_key "special_orders", "product_variants"
  add_foreign_key "special_orders", "stores"
  add_foreign_key "special_orders", "users", column: "created_by_user_id"
  add_foreign_key "special_orders", "vendors"
  add_foreign_key "store_display_locations", "display_locations"
  add_foreign_key "store_display_locations", "stores"
  add_foreign_key "store_tax_category_rates", "store_tax_rates"
  add_foreign_key "store_tax_category_rates", "stores"
  add_foreign_key "store_tax_category_rates", "tax_categories"
  add_foreign_key "store_tax_rates", "stores"
  add_foreign_key "stored_value_accounts", "customers"
  add_foreign_key "stored_value_accounts", "stores", column: "issuing_store_id"
  add_foreign_key "stored_value_identifiers", "stored_value_accounts"
  add_foreign_key "stored_value_identifiers", "stored_value_identifiers", column: "replaced_by_identifier_id"
  add_foreign_key "stored_value_ledger_entries", "stored_value_accounts"
  add_foreign_key "stored_value_ledger_entries", "stored_value_ledger_entries", column: "reverses_entry_id"
  add_foreign_key "stored_value_ledger_entries", "stored_value_reason_codes", column: "reason_code_id"
  add_foreign_key "stored_value_ledger_entries", "stores"
  add_foreign_key "stored_value_ledger_entries", "users", column: "created_by_user_id"
  add_foreign_key "stored_value_transfers", "stored_value_accounts", column: "from_account_id"
  add_foreign_key "stored_value_transfers", "stored_value_accounts", column: "to_account_id"
  add_foreign_key "stored_value_transfers", "stored_value_ledger_entries", column: "transfer_in_entry_id"
  add_foreign_key "stored_value_transfers", "stored_value_ledger_entries", column: "transfer_out_entry_id"
  add_foreign_key "stored_value_transfers", "stored_value_reason_codes", column: "reason_code_id"
  add_foreign_key "stored_value_transfers", "users", column: "created_by_user_id"
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
