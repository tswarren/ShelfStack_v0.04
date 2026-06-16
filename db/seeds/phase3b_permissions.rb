# frozen_string_literal: true

module Seeds
  module Phase3bPermissions
    PERMISSIONS = [
      { key: "setup.sub_departments.view", group: "setup", name: "View Subdepartments", description: "View subdepartments" },
      { key: "setup.sub_departments.create", group: "setup", name: "Create Subdepartments", description: "Create subdepartments" },
      { key: "setup.sub_departments.update", group: "setup", name: "Update Subdepartments", description: "Update subdepartments" },
      { key: "setup.sub_departments.inactivate", group: "setup", name: "Inactivate Subdepartments", description: "Inactivate subdepartments" },
      { key: "setup.sub_departments.reactivate", group: "setup", name: "Reactivate Subdepartments", description: "Reactivate subdepartments" },
      { key: "setup.sub_departments.delete", group: "setup", name: "Delete Subdepartments", description: "Delete unused subdepartments" },
      { key: "setup.category_schemes.view", group: "setup", name: "View Category Schemes", description: "View category schemes" },
      { key: "setup.category_schemes.create", group: "setup", name: "Create Category Schemes", description: "Create category schemes" },
      { key: "setup.category_schemes.update", group: "setup", name: "Update Category Schemes", description: "Update category schemes" },
      { key: "setup.category_schemes.inactivate", group: "setup", name: "Inactivate Category Schemes", description: "Inactivate category schemes" },
      { key: "setup.category_schemes.reactivate", group: "setup", name: "Reactivate Category Schemes", description: "Reactivate category schemes" },
      { key: "setup.category_schemes.delete", group: "setup", name: "Delete Category Schemes", description: "Delete unused category schemes" },
      { key: "setup.bisac_subjects.view", group: "setup", name: "View BISAC Subjects", description: "View BISAC subject import status" },
      { key: "setup.bisac_subjects.import", group: "setup", name: "Import BISAC Subjects", description: "Load or update BISAC subject category nodes" }
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
