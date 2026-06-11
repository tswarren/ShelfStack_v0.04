# frozen_string_literal: true

module Seeds
  module Phase3bPermissions
    PERMISSIONS = [
      { key: "setup.merchandise_classes.view", group: "setup", name: "View Merchandise Classes", description: "View merchandise classes" },
      { key: "setup.merchandise_classes.create", group: "setup", name: "Create Merchandise Classes", description: "Create merchandise classes" },
      { key: "setup.merchandise_classes.update", group: "setup", name: "Update Merchandise Classes", description: "Update merchandise classes" },
      { key: "setup.merchandise_classes.inactivate", group: "setup", name: "Inactivate Merchandise Classes", description: "Inactivate merchandise classes" },
      { key: "setup.merchandise_classes.reactivate", group: "setup", name: "Reactivate Merchandise Classes", description: "Reactivate merchandise classes" },
      { key: "setup.merchandise_classes.delete", group: "setup", name: "Delete Merchandise Classes", description: "Delete unused merchandise classes" },
      { key: "setup.category_schemes.view", group: "setup", name: "View Category Schemes", description: "View category schemes" },
      { key: "setup.category_schemes.create", group: "setup", name: "Create Category Schemes", description: "Create category schemes" },
      { key: "setup.category_schemes.update", group: "setup", name: "Update Category Schemes", description: "Update category schemes" },
      { key: "setup.category_schemes.inactivate", group: "setup", name: "Inactivate Category Schemes", description: "Inactivate category schemes" },
      { key: "setup.category_schemes.reactivate", group: "setup", name: "Reactivate Category Schemes", description: "Reactivate category schemes" },
      { key: "setup.category_schemes.delete", group: "setup", name: "Delete Category Schemes", description: "Delete unused category schemes" },
      { key: "setup.accounting_mappings.view", group: "setup", name: "View Accounting Mappings", description: "View sales account mappings" },
      { key: "setup.accounting_mappings.create", group: "setup", name: "Create Accounting Mappings", description: "Create sales account mappings" },
      { key: "setup.accounting_mappings.update", group: "setup", name: "Update Accounting Mappings", description: "Update sales account mappings" },
      { key: "setup.accounting_mappings.inactivate", group: "setup", name: "Inactivate Accounting Mappings", description: "Inactivate sales account mappings" },
      { key: "setup.accounting_mappings.reactivate", group: "setup", name: "Reactivate Accounting Mappings", description: "Reactivate sales account mappings" },
      { key: "setup.accounting_mappings.delete", group: "setup", name: "Delete Accounting Mappings", description: "Delete unused sales account mappings" },
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
