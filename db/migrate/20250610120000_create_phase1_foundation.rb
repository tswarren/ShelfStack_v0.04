# frozen_string_literal: true

class CreatePhase1Foundation < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.string :store_number, null: false, limit: 4
      t.string :store_group, limit: 5
      t.string :name, null: false, limit: 80
      t.string :shopping_center
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :country_code, null: false, limit: 2, default: "US"
      t.string :region_code, limit: 2
      t.string :postal_code, limit: 20
      t.string :phone, limit: 20
      t.string :fax, limit: 20
      t.string :email
      t.string :website_url
      t.string :time_zone, null: false, default: "America/New_York"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :stores, :store_number, unique: true
    add_index :stores, :store_group
    add_index :stores, :name
    add_index :stores, :active
    add_index :stores, [ :country_code, :region_code ]

    create_table :users do |t|
      t.string :user_type, null: false, default: "user"
      t.references :default_store, foreign_key: { to_table: :stores }
      t.string :username, null: false, limit: 50
      t.string :first_name, null: false, limit: 50
      t.string :last_name, null: false, limit: 50
      t.string :display_name, null: false, limit: 80
      t.string :clerk_number, limit: 10
      t.string :password_digest
      t.string :pin_digest
      t.datetime :password_changed_at
      t.datetime :pin_changed_at
      t.integer :invalid_login_attempts, null: false, default: 0
      t.datetime :locked_at
      t.datetime :previous_login_at
      t.datetime :last_login_at
      t.boolean :force_password_change, null: false, default: false
      t.boolean :interactive_login_enabled, null: false, default: true
      t.boolean :active, null: false, default: true
      t.datetime :deactivated_at
      t.timestamps
    end
    add_index :users, :username, unique: true
    add_index :users, :clerk_number, unique: true, where: "clerk_number IS NOT NULL"
    add_index :users, :user_type
    add_index :users, :active
    add_index :users, :locked_at

    create_table :permissions do |t|
      t.string :permission_key, null: false
      t.string :permission_group, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :permissions, :permission_key, unique: true
    add_index :permissions, :permission_group
    add_index :permissions, :active

    create_table :roles do |t|
      t.string :role_key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :system_role, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :roles, :role_key, unique: true
    add_index :roles, :name
    add_index :roles, :active
    add_index :roles, :system_role

    create_table :role_permissions do |t|
      t.references :role, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.timestamps
    end
    add_index :role_permissions, [ :role_id, :permission_id ], unique: true

    create_table :user_role_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.string :scope_type, null: false, default: "store"
      t.references :store, foreign_key: true
      t.boolean :active, null: false, default: true
      t.references :assigned_by_user, foreign_key: { to_table: :users }
      t.datetime :assigned_at
      t.timestamps
    end
    add_index :user_role_assignments, :scope_type
    add_index :user_role_assignments, :active
    add_index :user_role_assignments, [ :user_id, :role_id ],
              unique: true,
              where: "scope_type = 'global' AND active = true",
              name: "index_user_role_assignments_unique_global"
    add_index :user_role_assignments, [ :user_id, :role_id, :store_id ],
              unique: true,
              where: "scope_type = 'store' AND active = true",
              name: "index_user_role_assignments_unique_store"

    create_table :workstations do |t|
      t.references :store, null: false, foreign_key: true
      t.string :workstation_type, null: false
      t.string :workstation_number, null: false, limit: 3
      t.string :workstation_code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :workstations, :workstation_type
    add_index :workstations, :active
    add_index :workstations, [ :store_id, :workstation_number ], unique: true
    add_index :workstations, [ :store_id, :workstation_code ], unique: true

    create_table :workstation_assignments do |t|
      t.references :workstation, null: false, foreign_key: true
      t.string :assignment_token_digest, null: false
      t.references :assigned_by_user, foreign_key: { to_table: :users }
      t.datetime :assigned_at, null: false
      t.datetime :last_seen_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :workstation_assignments, :assignment_token_digest, unique: true
    add_index :workstation_assignments, :revoked_at
    add_index :workstation_assignments, :last_seen_at
    add_index :workstation_assignments, :workstation_id,
              unique: true,
              where: "revoked_at IS NULL",
              name: "index_workstation_assignments_one_active_per_workstation"

    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :store, foreign_key: true
      t.references :workstation, foreign_key: true
      t.string :session_token_digest, null: false
      t.string :status, null: false, default: "active"
      t.datetime :last_activity_at, null: false
      t.datetime :locked_at
      t.datetime :unlocked_at
      t.datetime :ended_at
      t.references :ended_by_user, foreign_key: { to_table: :users }
      t.string :ip_address
      t.text :user_agent
      t.timestamps
    end
    add_index :user_sessions, :session_token_digest, unique: true
    add_index :user_sessions, :status
    add_index :user_sessions, :last_activity_at
    add_index :user_sessions, :locked_at
    add_index :user_sessions, :ended_at

    create_table :audit_events do |t|
      t.references :actor_user, null: false, foreign_key: { to_table: :users }
      t.string :event_name, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.string :source_type
      t.bigint :source_id
      t.references :store, foreign_key: true
      t.references :workstation, foreign_key: true
      t.references :user_session, foreign_key: true
      t.datetime :occurred_at, null: false
      t.jsonb :event_details, null: false, default: {}
      t.timestamps
    end
    add_index :audit_events, :event_name
    add_index :audit_events, :occurred_at
    add_index :audit_events, [ :auditable_type, :auditable_id ]
    add_index :audit_events, [ :source_type, :source_id ]
    add_index :audit_events, [ :store_id, :occurred_at ]
  end
end
