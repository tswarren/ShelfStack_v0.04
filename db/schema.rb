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

ActiveRecord::Schema[8.1].define(version: 2025_06_11_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "default_margin_target_bps"
    t.string "default_pricing_model"
    t.integer "default_supplier_discount_bps"
    t.bigint "default_tax_category_id", null: false
    t.bigint "department_id", null: false
    t.string "name", null: false
    t.string "short_name", limit: 20, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_categories_on_active"
    t.index ["default_pricing_model"], name: "index_categories_on_default_pricing_model"
    t.index ["default_tax_category_id"], name: "index_categories_on_default_tax_category_id"
    t.index ["department_id", "name"], name: "index_categories_on_department_id_and_name", unique: true
    t.index ["department_id", "short_name"], name: "index_categories_on_department_id_and_short_name", unique: true
    t.index ["department_id", "sort_order"], name: "index_categories_on_department_id_and_sort_order"
    t.index ["department_id"], name: "index_categories_on_department_id"
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

  add_foreign_key "audit_events", "stores"
  add_foreign_key "audit_events", "user_sessions"
  add_foreign_key "audit_events", "users", column: "actor_user_id"
  add_foreign_key "audit_events", "workstations"
  add_foreign_key "categories", "departments"
  add_foreign_key "categories", "tax_categories", column: "default_tax_category_id"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "store_tax_category_rates", "store_tax_rates"
  add_foreign_key "store_tax_category_rates", "stores"
  add_foreign_key "store_tax_category_rates", "tax_categories"
  add_foreign_key "store_tax_rates", "stores"
  add_foreign_key "user_role_assignments", "roles"
  add_foreign_key "user_role_assignments", "stores"
  add_foreign_key "user_role_assignments", "users"
  add_foreign_key "user_role_assignments", "users", column: "assigned_by_user_id"
  add_foreign_key "user_sessions", "stores"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "user_sessions", "users", column: "ended_by_user_id"
  add_foreign_key "user_sessions", "workstations"
  add_foreign_key "users", "stores", column: "default_store_id"
  add_foreign_key "workstation_assignments", "users", column: "assigned_by_user_id"
  add_foreign_key "workstation_assignments", "workstations"
  add_foreign_key "workstations", "stores"
end
