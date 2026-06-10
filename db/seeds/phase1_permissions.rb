# frozen_string_literal: true

module Seeds
  module Phase1Permissions
    PERMISSIONS = [
      { key: "setup.access", group: "setup", name: "Access Setup", description: "Access the setup area" },
      { key: "setup.permissions.view", group: "setup", name: "View Permissions", description: "View permissions" },
      { key: "setup.roles.view", group: "setup", name: "View Roles", description: "View roles" },
      { key: "setup.roles.create", group: "setup", name: "Create Roles", description: "Create roles" },
      { key: "setup.roles.update", group: "setup", name: "Update Roles", description: "Update roles" },
      { key: "setup.roles.inactivate", group: "setup", name: "Inactivate Roles", description: "Inactivate roles" },
      { key: "setup.roles.reactivate", group: "setup", name: "Reactivate Roles", description: "Reactivate roles" },
      { key: "setup.roles.delete", group: "setup", name: "Delete Roles", description: "Delete unused roles" },
      { key: "setup.role_permissions.manage", group: "setup", name: "Manage Role Permissions", description: "Assign permissions to roles" },
      { key: "setup.users.view", group: "setup", name: "View Users", description: "View users" },
      { key: "setup.users.create", group: "setup", name: "Create Users", description: "Create users" },
      { key: "setup.users.update", group: "setup", name: "Update Users", description: "Update users" },
      { key: "setup.users.inactivate", group: "setup", name: "Inactivate Users", description: "Inactivate users" },
      { key: "setup.users.reactivate", group: "setup", name: "Reactivate Users", description: "Reactivate users" },
      { key: "setup.users.delete", group: "setup", name: "Delete Users", description: "Delete unused users" },
      { key: "setup.user_roles.manage", group: "setup", name: "Manage User Roles", description: "Assign roles to users" },
      { key: "setup.stores.view", group: "setup", name: "View Stores", description: "View stores" },
      { key: "setup.stores.create", group: "setup", name: "Create Stores", description: "Create stores" },
      { key: "setup.stores.update", group: "setup", name: "Update Stores", description: "Update stores" },
      { key: "setup.stores.inactivate", group: "setup", name: "Inactivate Stores", description: "Inactivate stores" },
      { key: "setup.stores.reactivate", group: "setup", name: "Reactivate Stores", description: "Reactivate stores" },
      { key: "setup.stores.delete", group: "setup", name: "Delete Stores", description: "Delete unused stores" },
      { key: "setup.workstations.view", group: "setup", name: "View Workstations", description: "View workstations" },
      { key: "setup.workstations.create", group: "setup", name: "Create Workstations", description: "Create workstations" },
      { key: "setup.workstations.update", group: "setup", name: "Update Workstations", description: "Update workstations" },
      { key: "setup.workstations.inactivate", group: "setup", name: "Inactivate Workstations", description: "Inactivate workstations" },
      { key: "setup.workstations.reactivate", group: "setup", name: "Reactivate Workstations", description: "Reactivate workstations" },
      { key: "setup.workstations.delete", group: "setup", name: "Delete Workstations", description: "Delete unused workstations" },
      { key: "sessions.lock", group: "sessions", name: "Lock Session", description: "Lock own session" },
      { key: "sessions.unlock", group: "sessions", name: "Unlock Session", description: "Unlock own session with PIN" },
      { key: "sessions.force_end", group: "sessions", name: "Force End Session", description: "Force end another user's locked session" },
      { key: "workstations.assign_browser", group: "workstations", name: "Assign Browser", description: "Assign browser to workstation" },
      { key: "workstations.reassign_browser", group: "workstations", name: "Reassign Browser", description: "Reassign browser to workstation" },
      { key: "audit_events.view", group: "audit_events", name: "View Audit Events", description: "View audit events" }
    ].freeze

    def self.seed!
      PERMISSIONS.each do |attrs|
        Permission.find_or_initialize_by(permission_key: attrs[:key]).tap do |permission|
          permission.permission_group = attrs[:group]
          permission.name = attrs[:name]
          permission.description = attrs[:description]
          permission.active = true
          permission.save!
        end
      end
    end
  end
end
